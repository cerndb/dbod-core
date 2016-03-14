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
with 'MooseX::Log::Log4perl';

use Data::Dumper;
use DBOD::Runtime;

my $runtime = DBOD::Runtime->new;

# input parameters
has 'instance' => ( is => 'ro', isa => 'Str', required => 1);
has 'metadata' => (is => 'rw', isa => 'HashRef', required => 1);
has 'config' => (is => 'ro', isa => 'HashRef');

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

