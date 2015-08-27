# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::PG;

use strict;
use warnings;

use Moose;
with 'MooseX::Log::Log4perl';

use Data::Dumper;

my $runtime = DBOD::Runtime->new;

#Starts a PostgreSQL database
sub StartPostgreSQL {
	my ($self,$entity, $pg_ctl, $pg_datadir) = @_;
	$self->log->info("Parameter: entity: <$entity> pg_ctl: <$pg_ctl> pg_datadir: <$pg_datadir>");
	my ($cmd, $rc, @output);

	#Check is instance is running
	#Check if server is running
	$rc = $self->CheckPostgreSQLState($pg_ctl,$pg_datadir) ;
	if ($rc == 0) {
		$self->log->debug("No instance running");
		$cmd = "/etc/init.d/pgsql_$entity start";
		$rc = $runtime->RunStr($cmd,\@output);
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
sub StopPostgreSQL {
	my ($self, $entity, $pg_ctl,$pg_datadir) = @_;
	$self->log->info("Parameters: entity: <$entity> pg_ctl: <$pg_ctl> pg_datadir: <$pg_datadir>");
	my ($cmd, $rc, @output);

	#Check if server is running
	$rc = $self->CheckPostgreSQLState($pg_ctl,$pg_datadir) ;
	if ($rc == 0) {
		$self->log->debug("No instance running. Nothing to do.");
		return 1;
	}
	else {
		#Put the instance down
		$cmd = "/etc/init.d/pgsql_$entity stop";
		$rc = $runtime->RunStr($cmd,\@output);
		if ($rc) {
			$self->log->debug("PostgreSQL shutdown completed");
			return 1; #ok
		} else  {
			$self->log->error("Problem shutting down PostgreSQL instance. Please check log.");
			return 0; #not ok
		}
	}
}


#It's up or down
sub CheckPostgreSQLState { 
	my ($self, $pg_ctl, $pg_datadir) = @_;
	$self->log->info("Parameters: pg_ctl: <$pg_ctl> pg_datadir: <$pg_datadir>");
	my ($cmd, $rc, @output); 


	#Check if server is running
	$cmd = "$pg_ctl status -D $pg_datadir -s";
	$rc = $runtime->RunStr($cmd,\@output);
	if ($rc == 0) {
		$self->log->error("No instance running. Nothing to do.");
		return 0;
	} else { 
		$self->log->debug("Instance running.");
		return 1; #ok	
	}
}  

1;

