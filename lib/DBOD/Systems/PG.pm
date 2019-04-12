# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Systems::PG;

use strict;
use warnings;

use Moose;
with 'DBOD::Instance';

use Data::Dumper;
use File::Basename;
use POSIX qw(strftime);

use DBOD;
use DBOD::Runtime;
use DBOD::Storage::NetApp::ZAPI;
use DBOD::Storage::NetApp::Snapshot;

has 'pg_ctl' => ( is => 'rw', isa => 'Str', required => 0);
has 'datadir' => ( is => 'rw', isa => 'Str', required => 0);

sub BUILD {

    my $self = shift;
    $self->datadir($self->metadata->{datadir});
    $self->pg_ctl($self->metadata->{bindir} . '/pg_ctl');

    my $ip_alias = 'dbod-' . lc $self->instance . ".cern.ch";
    $ip_alias =~ s/\_/\-/gx;
    $self->ip_alias($ip_alias);

    $self->logger->debug("Instance: " . $self->instance);
    $self->logger->debug("Datadir: " . $self->datadir);
    $self->logger->debug("pg_ctl: " . $self->pg_ctl);
    return;

};

sub _connect_db {
    my $self = shift;
    my $db_user = $self->config->{pgsql}->{db_user};
    my $db_password = $self->config->{pgsql}->{db_password};
    my $dsn;
    my $db_attrs;
    $self->log->info('Creating DB connection with instance');
    $dsn = "DBI:Pg:dbname=postgres;host=" . $self->ip_alias .
        ";port=" . $self->metadata->{port};
    $db_attrs = {
        AutoCommit => 1,
        RaiseError => 1,
    };
    $self->db(DBOD::DB->new(
            db_dsn  => $dsn,
            db_user => $db_user,
            db_password => $db_password,
            db_attrs => $db_attrs,));
    return;
}

sub ping() {
    my $self = shift;
    try {
        unless (defined $self->db()) {
            $self->_connect_db();
        }
        unless($self->db->do('delete from dod_ping') == 1) {
            $self->log->debug('Problem deleting entry from ping table');
            $self->log->debug("Database seems UP but not responsive");
            return $ERROR;
        };
        unless($self->db->do('insert into dod_ping select current_date, current_time') == 1) {
            $self->log->debug('Problem inserting entry into ping table');
            $self->log->debug("Database seems UP but not responsive");
            return $ERROR;
        }
        $self->log->info("Database is UP and responsive");
        return $OK;
    } catch {
        $self->log->error("Problem connecting to database. DB object:");
        $self->log->debug( Dumper $self->db() );
        return $ERROR;
    };

    return $OK;

}

#Starts a PostgreSQL database
sub start {
	my $self = shift;
    my $entity = 'dod_' . $self->instance();
	if ($self->is_running() == 0) {
		my $cmd = "/etc/init.d/pgsql_$entity start";
		my $rc = DBOD::Runtime::run_cmd(cmd => $cmd);
		if ($rc == $OK) {
			$self->log->info("PostgreSQL instance is up");
			return $OK;
		} else {
			$self->log->error("Problem starting instance. Please check log.");
			$self->log->error("Error code:" . $rc);
			return $ERROR;
		}
	}
	else{
		$self->log->info("Nothing to do");
		return $OK;
	}
}

#Stops a PostgreSQL database
sub stop {
	my $self = shift;
    my $entity = 'dod_' . $self->instance;
	if ($self->is_running()) {
		my $cmd = "/etc/init.d/pgsql_$entity stop";
		my $rc = DBOD::Runtime::run_cmd(cmd => $cmd);
		if ($rc == $OK) {
			$self->log->info("PostgreSQL shutdown completed");
			return $OK;
		} else  {
			$self->log->error("Problem shutting down instance. Please check log.");
			$self->log->error("Error code:" . $rc);
			return $ERROR;
		}
	}
	else {
		$self->log->info("Nothing to do.");
		return $OK;
	}
}

sub is_running {
	my $self = shift;
	my ($cmd, $rc);
	#Check if database server is running
	$cmd = $self->pg_ctl() . ' status -D ' . $self->datadir() . ' -s';
	$rc = DBOD::Runtime::run_cmd(cmd => $cmd);
	if ($rc == 0) {
		$self->log->info("Instance running.");
		return $TRUE;
	} else { 
		$self->log->info("Instance is not running");
		return $FALSE;
	}
}  

#TODO: Move server_zapi and volume name check to ZAPI call?
sub snapshot {
    my $self = shift;
    $self->log->info("Snapshot operation starting");
    if (! $self->is_running()) {
        $self->log->error("Snapshotting requires a running instance");
        return $ERROR;
    }

    unless (defined $self->db()) {
        $self->_connect_db();
    };

    # Get ZAPI server
    my $zapi = DBOD::Storage::NetApp::ZAPI->new( config => $self->config() );
    my ($server_zapi, $volume) = $self->_get_ZAPI_server_and_volume();
    return $ERROR unless ((defined $server_zapi) and (defined $volume));

    # Create snapshot label
    my $timetag = strftime "%d%m%Y_%H%M%S", gmtime;
    my $version = $self->metadata->{version};
    $version =~ tr/\.//d;
    my $snapname = "snapscript_" . $timetag . "_" . $version;
    # Snapshot preparation
    my $rc = $zapi->snap_prepare($server_zapi, $volume);
    if ($rc == $ERROR) {
        $self->log->error("Error preparing snapshot");
        return $ERROR;
    }

    # Set up backup_mode
    $rc = $self->db->do("SELECT pg_start_backup('${snapname}')");
    if ($rc != $TRUE) {
        $self->log->error("Error setting up backup mode");
        return $ERROR;
    }

    # Create snapshot
    $rc = $zapi->snap_create($server_zapi, $volume, $snapname);
    my $errorflag = 0;
    if ($rc == $ERROR ) {
        $errorflag = $ERROR;
        $self->log->error("Error creating snapshot");
    }

    # Disable backup mode
    $rc = $self->db->do("SELECT pg_stop_backup(), pg_create_restore_point('${snapname}')");
    if ($rc != $TRUE) {
        $self->log->error("Error stopping backup mode");
        return $ERROR;
    }

    if ($errorflag) {
        $self->log->error("Please check: snapshot was not properly taken.");
        return $ERROR;
    } else {
        $self->log->info("Snapshot operation successful");
        return $OK;
    }

}

sub _get_ZAPI_server_and_volume {
    my $self = shift;
    # Get ZAPI server
    my $zapi = DBOD::Storage::NetApp::ZAPI->new( config => $self->config() );
    my $datadir_nosuffix = dirname( $self->datadir() );
    my $arref = $zapi->get_server_and_volname( $datadir_nosuffix );
    my ($server_zapi, $volume_name) = @{$arref};
    if ((!defined $server_zapi) || (!defined $volume_name)) {
        $self->log->error( "Error generating ZAPI server" );
        return;
    }
    return ($server_zapi, $volume_name);
}

sub restore {
    my $self = shift;
    my ($snapshot, $pit) = @_;
    return $ERROR unless (defined $snapshot);

    $self->log->info('Restoring database to ' . $snapshot );
    $self->log->debug('Using ' . $pit) if (defined $pit);

    # Get ZAPI server controller object
    my $zapi = DBOD::Storage::NetApp::ZAPI->new( config => $self->config() );
    my ($zapi_server, $volume) = $self->_get_ZAPI_server_and_volume();
    return $ERROR unless ((defined $zapi_server) and (defined $volume));

    # Validate parameters validity
    my $actual_version =
        DBOD::Runtime::get_instance_version( $self->metadata->{'version'} );
    if (
        DBOD::Storage::NetApp::Snapshot::is_valid(
            $snapshot, $pit, $actual_version
        ) == $FALSE
    )
    {
        $self->log->error( 'Error validating snapshot file and/or PITR time' );
        return $ERROR;
    }

    # Stop database
    if ($self->is_running()) {
        return $ERROR if ($self->stop());
    }

    # Restore snapshot;
    my $rc = $zapi->snap_restore($zapi_server, $volume, $snapshot);
    if ($rc == $ERROR) {
        $self->log->error('Error restoring snapshot: ' . $snapshot);
        $self->log->error('Affected volume: ' . $volume);
        return $ERROR;
    }
    $self->log->info('Successfully restored snapshot ' . $snapshot);
    $self->log->debug('Affected volume: ' . $volume);

    # Re-start the database with disabled networking to perform
    # Crash recovery
    return $ERROR if $self->start( skip_networking => $TRUE);
	# TODO perform crash recovery
    # TODO: Implement PITR
	
    # Restart normally
    return $ERROR if ($self->stop());
    return $ERROR if ($self->start());

    return $OK;
}

1;

# pg_hba_local.conf
__DATA__
local	all				postgres 						trust
local 	dod_dbmon		dod_dbmon						trust
