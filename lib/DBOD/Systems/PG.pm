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
use DBOD;
use DBOD::Runtime;

has 'pg_ctl' => ( is => 'rw', isa => 'Str', required => 0);
has 'datadir' => ( is => 'rw', isa => 'Str', required => 0);

sub BUILD {

    my $self = shift;
    $self->datadir($self->metadata->{datadir});
    $self->pg_ctl($self->metadata->{bindir} . '/pg_ctl');

    my $ip_alias = 'dbod-' . lc $self->instance . ".cern.ch";
    $ip_alias =~ s/\_/\-/g;
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
        $self->log->debug("Database is UP and responsive");
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
		if ($rc) {
			$self->log->debug("PostgreSQL instance is up");
			return $OK;
		} else {
			$self->log->error("Problem starting instance. Please check log.");
			return $ERROR;
		}
	}
	else{
		$self->log->debug("Nothing to do");
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
		if ($rc) {
			$self->log->debug("PostgreSQL shutdown completed");
			return $OK;
		} else  {
			$self->log->error("Problem shutting down instance. Please check log.");
			return $ERROR;
		}
	}
	else {
		$self->log->debug("Nothing to do.");
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
		$self->log->info("Instance is not running");
		return $FALSE;
	} else { 
		$self->log->info("Instance running.");
		return $TRUE;
	}
}  

1;

