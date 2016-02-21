# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::MySQL;

use strict;
use warnings;

our $VERSION = 0.67;

use Moose;
with 'MooseX::Log::Log4perl';

use IPC::Run qw(run timeout);
use Net::OpenSSH;
use Data::Dumper;
use DBOD::Runtime;

my $runtime = DBOD::Runtime->new();

#Parses mysql error file after a certain string
sub parse_err_file {
	my ($self, $cad, $file) = @_;
	my $start = int(`grep \"$cad\" $file --line-number |tail -n1 |cut -d\":\" -f1`);
	my $total = int(`wc -l $file|cut -d\" \" -f1`);
	my $lines = $total - $start + 1;
	my $res = `tail $file -n $lines`;
	return $res;
}

sub check_state {
	my($self, $datadir) = @_;
	$self->log->info("Parameters: datadir: <$datadir>"); 

	my $rc=$runtime->run_str("ps -elf | grep -i datadir="  . $datadir . " | grep -v grep");

	if ($rc == 0) {
		$self->log->debug("Instance not running");
		return 0;

	} else {
		$self->log->debug("Instance is up.");
		return 1; #ok
	}
}

#Starts a MySQL database 
#local =1 -> skip network, local=0, it doesnt.
sub start {
	my ($self, $entity, $mysql_admin, $user, $password_dod_mysql, $mysql_socket, $mysql_datadir, $local) = @_;
       $self->log->info("Parameters: mysql_admin <$mysql_admin>, user: <$user>, password_dod_mysql: not displayed, mysql_socket: <$mysql_socket>"); 

	my ($cmd, $rc, @output);
	if (! defined $local) {
		$local =0;
	}
	#Check is instance is running
	if ( -r $ENV{"HOME"} . "/.my.cnf" ) {
		$cmd = "$mysql_admin  --socket=$mysql_socket ping";
	} else {
		$cmd = "$mysql_admin -u $user -p$password_dod_mysql --socket=$mysql_socket ping";
	}
	$rc = 0;
	$rc = $runtime->run_str($cmd, \@output, 0, "$mysql_admin -u $user -pXXXXXXXX --socket=$mysql_socket ping");

	my $log_search_string = "mysqld_safe Starting";
	my $hostname = `hostname`;
	chomp($hostname);
	my $log_error_file = "$mysql_datadir/$hostname.err";

	if ($rc == 0) {
		$self->log->debug("No instance running");
		if ($local==1) {
			$cmd = "/etc/init.d/mysql_$entity start --skip-networking";
		}
		else {
			$cmd = "/etc/init.d/mysql_$entity start";
		}
		my $rc1 = $runtime->run_str($cmd,\@output,0,$cmd);
		if ($rc1) {
			$self->log->debug("MySQL instance is up");
			$self->log->debug("mysqld output:\n\n" . $self->parse_err_file($log_search_string, $log_error_file));
			return 1; #ok
		} else {
			$self->log->error("Problem starting MySQL instance. Please check.");
			$self->log->error("mysqld output:\n\n" . $self->parse_err_file($log_search_string, $log_error_file));
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
	my ($self,$mysql_admin, $user, $password_dod_mysql, $mysql_socket) = @_;
	$self->log->info("Parameters: mysql_admin <$mysql_admin>, user: <$user>, password_dod_mysql: not displayed, mysql_socket: <$mysql_socket>"); 
	
	my ($cmd, $rc, @output);
	if ( -r $ENV{"HOME"} . "/.my.cnf" ) {
		$cmd = "$mysql_admin --socket=$mysql_socket ping";
	} else {
		$cmd = "$mysql_admin -u $user -p$password_dod_mysql --socket=$mysql_socket ping";
	}
	$rc = 0;
	$rc = $runtime->run_str($cmd,\@output, 0, "$mysql_admin -u $user -pXXXXXXXXX --socket=$mysql_socket ping");
	if ($rc == 0) {
		$self->log->error("No instance running. Nothing to do.");
		return 0;
	}
	else {
		#Put the instance down
		$self->log->error("Instance running. Shutting down");
		if ( -r $ENV{"HOME"} . "/.my.cnf" ) {
			$cmd = "$mysql_admin --socket=$mysql_socket shutdown";
		} else {
			$cmd = "$mysql_admin -u $user -p$password_dod_mysql --socket=$mysql_socket shutdown";
		}
		$rc = $runtime->run_str($cmd,\@output,0,"$mysql_admin -u $user -pXXXXXXXXXX  --socket=$mysql_socket shutdown");
		if ($rc) {
			$self->log->debug("MySQL shutdown completed");
			return 1; #ok
		} else  {
			$self->log->error("Problem shutting down MySQL instance. Please check.");
			return 0; #not ok
		}
	}	
}

1;

