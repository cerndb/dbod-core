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

use DBOD::Runtime;
my $runtime = DBOD::Runtime->new;

has 'pg_ctl' => ( is => 'rw', isa => 'Str', required => 0);
has 'datadir' => ( is => 'rw', isa => 'Str', required => 0);

sub BUILD {

    my $self = shift;
    $self->datadir($self->metadata->{datadir});
    $self->pg_ctl($self->metadata->{bindir} . '/pg_ctl');

    $self->logger->debug('Instance: '. $self->instance .
        "\ndatadir: " . $self->datadir . "\npg_ctl: " . $self->pg_ctl);
    return;
};

sub _connect_db {
    my $self = shift;
    my $db_user = $self->config->{pgsql}->{db_user};
    my $db_password = $self->config->{pgsql}->{db_password};
    my $dsn;
    my $db_attrs;
    $self->log->info('Creating DB connection with instance');
    $dsn = "DBI:Pg:dbname=postgres;host=dbod-" . $self->instance .
        ".cern.ch;port=" . $self->metadata->{port};
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

#Starts a PostgreSQL database
sub start {
	my $self = shift;
    my $entity = 'dod_' . $self->instance();
	if ($self->is_running() == 0) {
		my $cmd = "/etc/init.d/pgsql_$entity start";
		my $rc = $runtime->run_cmd(cmd => $cmd);
		if ($rc) {
			$self->log->debug("PostgreSQL instance is up");
			return 1; #ok
		} else {
			$self->log->error("Problem starting PostgreSQL instance. Please check log.");
			return 0; #notok
		}
	}
	else{
		$self->log->debug("Nothing to do");
		return 1;
	}
}

#Stops a PostgreSQL database
sub stop {
	my $self = shift;
    my $entity = 'dod_' . $self->instance;
	if ($self->is_running()) {
		my $cmd = "/etc/init.d/pgsql_$entity stop";
		my $rc = $runtime->run_cmd(cmd => $cmd);
		if ($rc) {
			$self->log->debug("PostgreSQL shutdown completed");
			return 1; #ok
		} else  {
			$self->log->error("Problem shutting down PostgreSQL instance. Please check log.");
			return 0; #not ok
		}
	}
	else {
		$self->log->debug("Nothing to do.");
		return 1;
	}
}

sub is_running {
	my $self = shift;
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

