# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Systems::MySQL;

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

# input parameters
has 'instance' => ( is => 'ro', isa => 'Str', required => 1);
has 'metadata' => (is => 'rw', isa => 'HashRef', required => 1);
has 'config' => (is => 'ro', isa => 'HashRef');

has 'datadir' => ( is => 'rw', isa => 'Str', required => 0);
has 'socket' => ( is => 'rw', isa => 'Str', required => 0);
has 'mysql_admin' => ( is => 'rw', isa => 'Str', required => 0);


sub BUILD {

	my $self = shift;

    # Metadata unpacking
	$self->datadir($self->metadata->{datadir});
	$self->mysql_admin($self->metadata->{bindir} . '/mysqladmin');
    $self->socket($self->metadata->{socket});

    my $ip_alias = 'dbod-' . lc $self->instance() . ".cern.ch";
    $ip_alias =~ s/\_/\-/g;
    $self->ip_alias($ip_alias);

    $self->logger->debug("Instance: " . $self->instance);
    $self->logger->debug("Datadir: " . $self->datadir);
    $self->logger->debug("mysql_admin: " . $self->mysql_admin);
    $self->logger->debug('Socket: ' . $self->socket);
	return;
};

sub _connect_db {
    my $self = shift;
    # Set up db connector
    my $db_user = $self->config->{mysql}->{'db_user'};
    my $db_password = $self->config->{mysql}->{'db_password'};
    my $dsn;
    my $db_attrs;
    $self->log->info('Creating DB connection with instance');
    $dsn = 'DBI:mysql:host=' . $self->ip_alias . ';port=' . $self->metadata->{port};
    $db_attrs = {
        AutoCommit => 1,
    };
    $self->db(DBOD::DB->new(
            db_dsn  => $dsn,
            db_user => $db_user,
            db_password => $db_password,
            db_attrs => $db_attrs,));
    return;
}

#Parses mysql error file after a certain string
sub _parse_err_file {
	my ($self, $cad, $file) = @_;
    my ($buf, $start, $total, $res, @buf);
    my $error = DBOD::Runtime::run_cmd(
        cmd => "grep ${cad} ${file} --line-number",
        output => \$buf);
    if ($error) {
        return;
    }
    @buf = split m{/\n/}x, $buf; # Split into lines
    my $last_line = pop @buf; # Take last appearance
    @buf = split m{/ /}x, $last_line; # Split into fields
    $start = int($buf[0]); # Convert first field to numeric
    DBOD::Runtime::run_cmd(
        cmd => "wc -l $file",
        output => \$total);
    @buf = split m{/ /}x, $last_line; # Split into fields
    $start = int($buf[0]); # Convert first field to numeric
	my $lines = int($total) - int($start) + 2;
    DBOD::Runtime::run_cmd(
        cmd => "tail $file -n $lines",
        output => \$res);
	return $res;
}

sub _binary_log{
    my $self = shift;
    if (! defined $self->db()){
        $self->_connect_db();
    }
    my $rows = $self->db->select("show master status");
    if (scalar @{$rows} != 1) {
        $self->log->error("Error querying master status");
        return;
    }
    # Unpacking result
    my @buf = @{$rows};
    my @row = @{$buf[0]}[0];
    $self->log->debug('Current binary log file: ' . $row[0]);
    return $row[0];
}

sub is_running {
	my $self = shift;
    my ($output, @buf);
	my $error = DBOD::Runtime::run_cmd(
        cmd => "ps -u mysql -f",
        output => \$output);
    if (! $error) {
        @buf = split m{/\n/}x, $output;
        my $datadir = $self->datadir();
        my @search = grep {/$datadir/} @buf;
        if (scalar @search) {
            $self->log->debug( "Instance is running" );
            return $TRUE;
        } else {
            $self->log->debug( "Instance not running" );
            return $FALSE;
        }
    } else {
        $self->log->error("Problem getting process list");
        return $FALSE;
    }
}

sub ping {
    my $self = shift;
    try {
        unless (defined $self->db()) {
            $self->_connect_db();
        }
        unless($self->db->do('delete from dod_dbmon.ping') == 1) {
            $self->log->debug('Problem deleting entry from ping table');
            $self->log->debug("Database seems UP but not responsive");
            return $ERROR;
        };
        unless($self->db->do('insert into dod_dbmon.ping values (curdate(), curtime())') == 1) {
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

#Starts a MySQL database 
sub start {
    my ($self, %args) = @_;
    my $skip_networking = ( defined ($args{skip_networking}) ? $args{skip_networking}: 0 );

    my $entity = 'dod_' . $self->instance;

	if ($self->is_running()) {
        $self->log->debug("Nothing to do");
        return $OK;
	}
	else{
        my ($cmd);
        my $log_search_string = "mysqld_safe Starting";
        my $hostname;
        DBOD::Runtime::run_cmd(cmd => 'hostname', output => \$hostname);
        chomp($hostname);
        my $log_error_file = $self->datadir() . "/$hostname.err";
        if ($skip_networking) {
            $cmd = "/etc/init.d/mysql_$entity start --skip-networking";
        }
        else {
            $cmd = "/etc/init.d/mysql_$entity start";
        }
        my $error = DBOD::Runtime::run_cmd( cmd => $cmd );
        if ($error) {
            $self->log->error("Problem starting MySQL instance. Please check.");
            $self->log->error("mysqld output:\n\n" .
                    $self->_parse_err_file($log_search_string, $log_error_file));
            return $ERROR;
        } else {
            $self->log->debug("MySQL instance is up");
            $self->log->debug("mysqld output:\n\n" .
                    $self->_parse_err_file($log_search_string, $log_error_file));
            return $OK;
        }
	}
}

#Stops a MySQL database
sub stop {
	my $self = shift;
    my $entity = 'dod_' . $self->instance;
	if ($self->is_running()) {
        my ($cmd, $error);
		#Put the instance down
		$self->log->debug("Shutting down");
        $cmd = '/etc/init.d/mysql_'. $entity . ' stop';
		$error = DBOD::Runtime::run_cmd( cmd => $cmd);
		if ($error) {
            $self->log->error("Problem shutting down MySQL instance. Please check.");
            return $ERROR; #not ok
		} else  {
            $self->log->debug("Shutdown completed");
            return $OK;
		}
	}
    else{
        $self->log->error("Nothing to do.");
        return $OK;
    }
}

sub snapshot {
    my $self = shift;

    if (! $self->is_running()) {
        $self->log->error("Snapshotting requires a running instance");
        return $ERROR;
    }

    # Get ZAPI server
    my $zapi = DBOD::Storage::NetApp::ZAPI->new(config => $self->config());
    my $datadir_nosuffix = dirname($self->datadir());
    my $arref = $zapi->get_server_and_volname($datadir_nosuffix);

    my ($server_zapi, $volume_name) = @{$arref};

    if ((! defined $server_zapi) || (! defined $volume_name)) {
        $self->log->error("Error generating ZAPI server");
        return $ERROR;
    }

    # Snapshot preparation
    my $rc = $zapi->snap_prepare($server_zapi, $volume_name);
    if ($rc == $ERROR) {
        $self->log->error("Error preparing snapshot");
        return $ERROR;
    }

    # Pre-snapshot actions
    $rc = $self->db->do("flush tables with read lock");
    if ($rc != $TRUE) {
        $self->log->error("Error flushing tables");
        return $ERROR;
    }
    $rc = $self->db->do("flush logs");
    if ($rc != $TRUE) {
        $self->log->error("Error flushing logs. Aborting snapshot");
        if ($self->db->do("unlock tables") != $TRUE){
            $self->log->error("Error unlocking tables! Please contact an admin");
        };
        return $ERROR;
    }

    my $binlog_file = $self->_binary_log();
    my ($log_prefix, $log_sequence) = split /\./, $binlog_file;
    if (! defined $log_sequence || ! defined $log_prefix) {
        $self->log->error("Actual log_sequence couldnt be determined. Please check.");
        return $ERROR;
    }

    # Create snapshot label (Missing version at the end)
    my $log_num;
    if (int($log_sequence) > 0) {
        $log_num = int($log_sequence) + 1;
    }
    my $timetag = strftime "%d%m%Y_%H%M%S", gmtime;
    my $version = $self->metadata->{version};
    $version =~ tr/\.//d;
    my $snapname = "snapscript_" . $timetag . "_" . $log_num . "_" . $version;

    # Create snapshot
    $rc = $zapi->snap_create($server_zapi, $volume_name, $snapname);
    my $errorflag = $OK;
    if ($rc == $ERROR ) {
        $errorflag = $ERROR;
        $self->log->error("Error creating snapshot");
    }

    # Disable backup mode
    $rc = $self->db->do("unlock tables");
    if ($rc != $TRUE) {
        $self->log->error("Error unlocking tables! Please contact an admin");
        return $ERROR;
    }
    return $errorflag;
}

1;

