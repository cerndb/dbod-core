# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::MySQL;

use strict;
use warnings;

our $VERSION = 0.68;

use Moose;
extends 'DBOD::Instance';

use IPC::Run qw(run timeout);
use Net::OpenSSH;
use Data::Dumper;
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

	$self->logger->debug('Instance: '. $self->instance .
			' datadir: ' . $self->datadir . ' mysql_admin: '. $self->mysql_admin .
            ' socket: ' . $self->socket);
	return;
};

sub _connect_db {
    my $self = shift;
    if (defined $self->metadata->{'subcategory'}) {
        # Set up db connector
        my $db_type = lc $self->metadata->{'subcategory'};
        my $db_user = $self->config->{$db_type}->{'db_user'};
        my $db_password = $self->config->{$db_type}->{'db_password'};
        my $dsn;
        my $db_attrs;
        $self->log->info('Creating DB connection with instance');
        $dsn = "DBI:mysql:mysql_socket=" . $self->metadata->{'socket'};
        $db_attrs = {
            AutoCommit => 1,
        };
        $self->db(DBOD::DB->new(
                db_dsn  => $dsn,
                db_user => $db_user,
                db_password => $db_password,
                db_attrs => $db_attrs,));
    }
    else {
        $self->log->info('Skipping DB connection with instance');
    }
    return;
}

#Parses mysql error file after a certain string
sub parse_err_file {
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
		return 1;
	} else {
		$self->log->debug("Instance not running");
		return 0; #ok
	}
}

#Starts a MySQL database 
sub start {
    my $self = shift;
    my %args = @_;
    my $skip_networking = ( defined ($args{skip_networking}) ? $args{skip_networking}: 0 );

    my $entity = 'dod_' . $self->instance;

	unless ($self->is_running()) {
        my ($cmd);
        my $log_search_string = "mysqld_safe Starting";
        my $hostname;
        $runtime->run_cmd(cmd => 'hostname', output => \$hostname);
        chomp($hostname);
        my $log_error_file = $self->datadir() . "/$hostname.err";
		$self->log->debug("No instance running");
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
                    $self->parse_err_file($log_search_string, $log_error_file));
			return 1; #ok
		} else {
			$self->log->error("Problem starting MySQL instance. Please check.");
			$self->log->error("mysqld output:\n\n" .
                    $self->parse_err_file($log_search_string, $log_error_file));
			return 0; #notok
		}
	}
	else{
		$self->log->debug("The instance was running. Nothing to do");
		return 1;
	}
}

#Stops a MySQL database
sub stop {
	my ($self) = @_;
    my $entity = 'dod_' . $self->instance;
	if ($self->is_running()) {
        my ($cmd, $rc);
		#Put the instance down
		$self->log->debug("Instance is running. Shutting down");
        $cmd = '/etc/init.d/mysql_'. $entity . ' stop';
		$rc = $runtime->run_cmd( cmd => $cmd);
		if ($rc) {
			$self->log->debug("MySQL shutdown completed");
			return 1; #ok
		} else  {
			$self->log->error("Problem shutting down MySQL instance. Please check.");
			return 0; #not ok
		}
	}
    else{
        $self->log->error("No instance running. Nothing to do.");
        return 0;
    }
}

1;

