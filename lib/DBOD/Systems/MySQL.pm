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
use DBOD;
use DBOD::Runtime;

my $runtime = DBOD::Runtime->new();
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
# TODO: refactor to use run_cmd
sub _parse_err_file {
	my ($self, $cad, $file) = @_;
	my $start = int(`grep \"$cad\" $file --line-number |tail -n1 |cut -d\":\" -f1`);
	my $total = int(`wc -l $file|cut -d\" \" -f1`);
	my $lines = $total - $start + 1;
	my $res = `tail $file -n $lines`;
	return $res;
}

sub is_running {
	my $self = shift;
	my $rc = $runtime->run_cmd(
        cmd => "ps -elf | grep -i datadir="  . $self->datadir);
	if ($rc == 0) {
		$self->log->debug("Instance is running");
		return $TRUE;
	} else {
		$self->log->debug("Instance not running");
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
    my $self = shift;
    my %args = @_;
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
        $runtime->run_cmd(cmd => 'hostname', output => \$hostname);
        chomp($hostname);
        my $log_error_file = $self->datadir() . "/$hostname.err";
        if ($skip_networking) {
            $cmd = "/etc/init.d/mysql_$entity start --skip-networking";
        }
        else {
            $cmd = "/etc/init.d/mysql_$entity start";
        }
        my $rc = $runtime->run_cmd( cmd => $cmd );
        if ($rc) {
            $self->log->debug("MySQL instance is up");
            $self->log->debug("mysqld output:\n\n" .
                    $self->_parse_err_file($log_search_string, $log_error_file));
            return $OK;
        } else {
            $self->log->error("Problem starting MySQL instance. Please check.");
            $self->log->error("mysqld output:\n\n" .
                    $self->_parse_err_file($log_search_string, $log_error_file));
            return $ERROR;
        }
	}
}

#Stops a MySQL database
sub stop {
	my ($self) = @_;
    my $entity = 'dod_' . $self->instance;
	if ($self->is_running()) {
        my ($cmd, $rc);
		#Put the instance down
		$self->log->debug("Shutting down");
        $cmd = '/etc/init.d/mysql_'. $entity . ' stop';
		$rc = $runtime->run_cmd( cmd => $cmd);
		if ($rc) {
			$self->log->debug("Shutdown completed");
			return $OK;
		} else  {
			$self->log->error("Problem shutting down MySQL instance. Please check.");
			return $ERROR; #not ok
		}
	}
    else{
        $self->log->error("Nothing to do.");
        return $OK;
    }
}

1;

