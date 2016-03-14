# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::PG;

use strict;
use warnings;

our $VERSION = 0.68;

use Moose;
extends 'DBOD::Instance';

use Data::Dumper;
use DBOD::Runtime;

my $runtime = DBOD::Runtime->new;

has 'pg_ctl' => ( is => 'rw', isa => 'Str', required => 0);
has 'datadir' => ( is => 'rw', isa => 'Str', required => 0);

sub BUILD {

    my $self = shift;
    $self->datadir($self->metadata->{datadir});
    $self->pg_ctl($self->metadata->{bindir} . '/pg_ctl');

    $self->logger->debug('Instance: '. $self->instance .
        ' datadir: ' . $self->datadir . ' pg_ctl: '. $self->pg_ctl);
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
        $dsn = "DBI:Pg:dbname=postgres;host=" . $self->metadata->{'socket'}.
            ";port=" . $self->metadata->{'port'};
        $db_attrs = {
            AutoCommit => 1,
            RaiseError => 1,
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

#Starts a PostgreSQL database
sub start {
	my ($self) = @_;
	my ($cmd, $rc);
    my $entity = 'dod_' . $self->instance;

	#Check is instance is running
	#Check if server is running
	$rc = $self->is_running() ;
	if ($rc == 0) {
		$self->log->debug("No instance running");
		$cmd = "/etc/init.d/pgsql_$entity start";
		$rc = $runtime->run_cmd(cmd => $cmd);
		if ($rc) {
			$self->log->debug("PostgreSQL instance is up");
			return 1; #ok
		} else {
			$self->log->error("Problem starting PostgreSQL instance. Please check log.");
			return 0; #notok
		}
	}
	else{
		$self->log->debug("The instance was running. Nothing to do");
		return 1;
	}
}

#Stops a PostgreSQL database
sub stop {
	my $self = shift;
	my ($cmd, $rc);
    my $entity = 'dod_' . $self->instance;
	#Check if server is running
	$rc = $self->is_running() ;
	if ($rc == 0) {
		$self->log->debug("No instance running. Nothing to do.");
		return 1;
	}
	else {
		# Stops instance
		$cmd = "/etc/init.d/pgsql_$entity stop";
		$rc = $runtime->run_cmd(cmd => $cmd);
		if ($rc) {
			$self->log->debug("PostgreSQL shutdown completed");
			return 1; #ok
		} else  {
			$self->log->error("Problem shutting down PostgreSQL instance. Please check log.");
			return 0; #not ok
		}
	}
}

sub is_running {
	my ($self) = @_;
	my ($cmd, $rc);
	#Check if database server is running
	$cmd = $self->pg_ctl() . ' status -D ' . $self->datadir() . ' -s';
	$rc = $runtime->run_cmd(cmd => $cmd);
	if ($rc == 0) {
		$self->log->info("Instance is not running");
		return 0;
	} else { 
		$self->log->info("Instance running.");
		return 1;
	}
}  

1;

