# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Runtime;

use strict;
use warnings;

our $VERSION = 0.68;

use Moose;
with 'MooseX::Log::Log4perl';

use Try::Tiny;
use IPC::Run qw(run timeout);
use Net::OpenSSH;
use Data::Dumper;
use File::Temp;
use File::Copy;
use Time::Local;
use Time::localtime;

sub run_cmd {
    my ($self, $cmd_str, $timeout) = @_;
    my @cmd = split ' ', $cmd_str ;
    my ($out, $err);
    try {
        if (defined $timeout) {
            $self->log->debug("Executing ${cmd_str} with timeout: ${timeout}");
            run \@cmd, ,'>', \$out, '2>', \$err, (my $t = timeout $timeout);
        }
        else {
            $self->log->debug("Executing ${cmd_str}");
            run \@cmd, ,'>', \$out, '2>', \$err;
        }
        # If the command executed succesfully we return its exit code
        $self->log->debug("${cmd_str} stdout: " . $out);
        $self->log->debug("${cmd_str} return code: " . $?);
        return scalar $?;
    } 
    catch {
        if ($_ =~ /^IPC::Run: .*timeout/) {
            # Timeout exception
            $self->log->error("Timeout exception: " . $_);
            $self->log->error("CMD stderr: " . $err);
            return;
        }
        else {
            # Other type of exception ocurred
            $self->log->error("Exception found: " . $_);
            $self->log->error("CMD stderr: " . $err);
            return;
        }
    };
    return;
}

sub mywait {
    my ($self, $method, @params) = @_;
    my $result;
    $self->log->debug( "Calling $method with @params until obtaining results");
    $result= $method->(@params);
    my $time = 1.0;
    while (! defined $result) {
        $self->log->debug( "Received: $result. Waiting $time seconds" );
        sleep $time;
        $time = $time * 2;
        $result = $method->(@params);
    }
    $self->log->debug($result);
    return $result;
}

sub result_code{
    my ($self, $log) = @_;
    my @lines = split(m{\n}x, $log);
    my $code = undef;
    foreach (@lines){
        if ( $_ =~ m{\[(\d)\]}x ){
            $code = $1;
            print $_,"\n";
            print $code,"\n";
        }
    }
    if (defined $code){
        return scalar int($code);
    }
    else{
        # If the command doesn't return any result code, we take it as bad
        return scalar 1;
    }
}

sub ssh {
    my ($self, $arg_ref) = @_; 
    # Using named parameters, but unpacking for clarity and usability
    my $user = $arg_ref->{user};
    my $host = $arg_ref->{host};
    my $cmd = $arg_ref->{cmd};
    my $ssh;
    $self->log->debug("Opening SSH connection ${user}\@${host}");
    $ssh = Net::OpenSSH->new("$user\@$host",
        password => $arg_ref->{password},
        master_stdout_discard => 0,
        master_stderr_discard => 1);
    if ($ssh->error) {
        $self->log->error("SSH connection error: " . $ssh->error);
        return;
    }    
    $self->log->debug("Executing SSH ${cmd} at ${host}");
    my($stdout, $stderr) = $ssh->capture2({timeout => 60 }, $cmd); 
    if ($ssh->error) {
        $self->log->error("SSH Error: " . $ssh->error);
        $self->log->error("SSH Stdout: " . $stdout);
        $self->log->error("SSH Stderr: " . $stderr);
        return;
    }
    return scalar $stdout;
}

sub scp_get {
    my ($self, $arg_ref) = @_; 
    # Using named parameters, but unpacking for clarity and usability
    my $user = $arg_ref->{user};
    my $host = $arg_ref->{host};
    my $path_from = $arg_ref->{path_from};
    my $path_to = $arg_ref->{path_to};
    my $ssh;
    $self->log->debug("Opening SSH connection ${user}\@${host}");
    $ssh = Net::OpenSSH->new("$user\@$host",
        password => $arg_ref->{password},
        master_stdout_discard => 0,
        master_stderr_discard => 1,
        master_opts => [-o => "StrictHostKeyChecking=no",
                        -o => "UserKnownHostsFile=/dev/null"]);
    if ($ssh->error) {
        $self->log->error("SSH connection error: " . $ssh->error);
        return;
    }
    $self->log->debug("Executing scp_get ${path_from}, ${path_to}");
    $ssh->scp_get({recursive => 1}, $path_from, $path_to);
    if ($ssh->error) {
        $self->log->error("SSH Error: " . $ssh->error);
        return; 
    }
    return scalar 1;
}

# TODO: If this is not needed for MySQL upgrades, move to pg_upgrade
#@deprecated  This method should be considered redundant as the instance version
# Can and should be read from the instance metadata.
sub is_running_different_version {
	my($self,$file,$versiontogo)=@_;
	$self->log->info("Parameters file: <$file>, versiontogo: <$versiontogo>");

	if (-e "$file") {
		my(@arr)=$self->read_file("$file");
		if (scalar(@arr) ==0 ) {
			$self->log->error("file <$file>  is empty. Strange.");
			return 0; #notgood
		} else {
			foreach (@arr) {
				if (/(\d+)\.(\d+)\.(\d+)/) {
					chomp $_;
					if ($_ eq "$versiontogo") {
						$self->log->error("You are already running <$versiontogo>");
						return 0; #not good
					} else {
						$self->log->debug("actual version <$_> different of upgrade version <$versiontogo>.");
						return 1; #ok
					} 
				}
			} 
		} 
	} else {   
		$self->log->error("<$file> file doesnt exist");   
		return 0;#not good
	}
	return;
}
 
# Method to implement a timeout while checking a condition.
# Condition should be implemented by a routine
sub timeout_one_param {
	my($self,$timeout,$poll_interval,$test_condition,$oneparam) = @_;
	$self->log->info("Parameters timeout: <$timeout>, poll_interval: <$poll_interval>, test_condition: <$test_condition> oneparam: <$oneparam>");

	until ($test_condition->($oneparam) || $timeout <= 0)
	{
       	$timeout -= $poll_interval;
	 	sleep $poll_interval;
	}
	
	if ($timeout > 0) {
		return 1; #ok
	} else {
		return 0; # not ok
	}
	
}
# TODO: Test refactored method and remove this implementation
#@deprecated
sub check_times {
	my ($self, $snapshot, $pitr, $version_snap) = @_;
	my($numsecs_restore);	
	if ( $snapshot =~ /snapscript_(\d\d)(\d\d)(\d\d\d\d)_(\d\d)(\d\d)(\d\d)_(\d+)/x ) {
		my($year_snap,$month_snap,$day_snap,$hour_snap,$min_snap,$sec_snap);
			$year_snap=$3;
			$month_snap=$2;
			$day_snap=$1;
			$hour_snap=$4;
			$min_snap=$5;
			$sec_snap=$6;
			$$version_snap=$7;
			if (defined $$version_snap) {
				$self->log->debug("snap restore: year: <$year_snap> month: <$month_snap> day: <$day_snap> hour: <$hour_snap> min: <$min_snap> sec: <$sec_snap> version_snap: <$$version_snap>");
			} else {
				$self->log->debug("snap restore: year: <$year_snap> month: <$month_snap> day: <$day_snap> hour: <$hour_snap> min: <$min_snap> sec: <$sec_snap> version_snap: <not available>");
			}
			try {
				$numsecs_restore=timelocal($sec_snap,$min_snap,$hour_snap,$day_snap,($month_snap -1),$year_snap);

			} catch {
				$self->log->error("Problem with timelocal <$!>  numsecs: <$numsecs_restore>");	
				if (defined $_[0]) {
					$self->log->error("Cought error: $_[0]");	
				}
				return 0;
			};
	} else {
			$self->log->error("problem parsing <" . $snapshot . ">");	
			return 0;
	}
	
 	my($numsecs_pitr);
	if (defined $pitr) {
			if ($pitr =~ /(\d\d\d\d)-(\d\d)-(\d\d)_(\d+):(\d+):(\d+)/x) {
			my($year_pitr,$month_pitr,$day_pitr,$hour_pitr,$min_pitr,$sec_pitr);
			$year_pitr=$1;
			$month_pitr=$2;
			$day_pitr=$3;
			$hour_pitr=$4;
			$min_pitr=$5;
			$sec_pitr=$6;
			
			$self->log->debug("year: <$year_pitr> month: <$month_pitr> day: <$day_pitr> hour: <$hour_pitr> min: <$min_pitr> sec: <$sec_pitr>");
			if ($month_pitr > 12 ) {
				$self->log->error("PITR: not right time format <" . $pitr . ">");
				$self->pitr(undef);
			}
			try {
				$numsecs_pitr=timelocal($sec_pitr,$min_pitr,$hour_pitr,$day_pitr,($month_pitr -1),$year_pitr);

			} catch {
				$self->log->error("Problem with timelocal <$!> . numsecs: <$numsecs_pitr>");
				if (defined $_[0]) {
					$self->log->error("Cought error: $_[0]");	
				}
				return 0;
			};
			if ($numsecs_pitr < $numsecs_restore) {
				$self->log->error("Time to pitr <" . $pitr . "> makes no sense for a restore: <" . $snapshot . ">");
				return 0;

			}
			if ($snapshot =~ /_cold$/x) {
				if ($numsecs_pitr < ($numsecs_restore + 15)) {
					$self->log->error("Using a cold snapshot <" . $snapshot . ">, PITR should at least 15 seconds later than snapshot!.");
					return 0;
				}
			} 		
		} else {
			$self->log->error("Problem parsing <" . $pitr . ">");
			return 0;
		}
    } elsif ( $snapshot =~ /_cold$/x ) {
		$self->log->error("No PITR given and cold snapshot selected!.");
		return 0;
    }
    return 1;	
	
}

#@deprecated To be substutituted by run_cmd
sub run_str {
	my($self, $cmd,$str,$fake,$text) = @_; 
	if (defined $text) {
		$self->log->info("Parameters cmd: not displayed");
	       $self->log->info("Parameters text: <$text>");
	} else {
		$self->log->info("Parameters cmd: $cmd");
	}
       $self->log->info("Parameters fake: <$fake>") if defined $fake;


	my($rc); 
       if ($fake) {
		if (defined $text) {
			$self->log->debug("Would do $text");
		} else {
			$self->log->debug("Would do $cmd");
		} 
	} else {
		if (defined $text) {
			$self->log->debug("Running $text");
		} else {
			$self->log->debug("Running $cmd");
		}  

		@$str=`$cmd`;
		$rc=$?;
		if ($rc != 0) {
			$self->log->error(" failed $! and return code: <$rc>");
			return 0; #error
		}
	}
	return 1; #ok
} 

#
sub get_IP_from_cname {
	my ($self, $name) = @_;
	$self->log->info("Parameters name: <$name>");

	my (@output,$rc);
	my $cmd="ping -c 1 $name";

	$rc=$self->run_str($cmd,\@output);

	if ($rc) {
		foreach (@output) {
			if (/PING .*? \((\d+\.\d+\.\d+\.\d+)\) /) {
				my($ip)=$1;
				$self->log->debug("IP <" . $ip . "> for <$name>");
				return $1;
			}
		}
	} else {
		$self->log->debug("Problem retrieving IP from <$name>: @output");
		return 0;
	}
	return 0; 
}

sub retrieve_user_password {
	my ($self, $user) = @_;
	my $password;
	$self->log->info("Parameters user: <$user>");
	my($basepathtosys)=`/etc/init.d/syscontrol sc_configuration_directory`;
	chomp 	$basepathtosys;
	
	if (-e "$basepathtosys/projects/systools/bin/get_passwd" ) {
		$password=`$basepathtosys/projects/systools/bin/get_passwd $user`; 
		if (defined $password && length($password) > 0) {
			$self->log->debug("Password found for <$user>");
			return $password;
		}
	}

	$self->log->debug("Password not found for <$user>");	
	return;
 
}

# TODO: This can be a generic operation to have as a Job Class method
sub get_instance_version {
	my($self,$file)=@_;
	$self->log->info("Parameters file: <$file>");
	if (-e "$file") {
		my(@arr)=$self->read_file("$file");
		if (scalar(@arr) ==0 ) {
			$self->log->error("File <$file>  is empty. Strange.");
			return;
		} else {
			foreach (@arr) {
				if (/(\d+)\.(\d+)\.(\d+)/) {
					$self->log->debug("Version <$1$2$3>."); 
					return "$1$2$3";
				}
			}   
		} 
	} else {   
		$self->log->error("<$file> file doesnt exist"); 
	}  
	return;
}

sub read_file {
	my ($self, $file) = @_;
	$self->log->info("Parameters file: <$file>");
	open my $F, '<', $file || $self->log->error("Cant read file $file. Error: $! ");
	my (@text) = <$F>;
	close($F);
	return @text;
}

sub write_file_arr {
	my ($self, $file, $text) = @_;
	$self->log->info("Parameters file: <$file> text: just_number_of_lines " . scalar(@$text) );
  	open my $F, '>', $file || $self->log->debug("cant write <$file>");
	foreach (@$text) {
  		print $F $_;
	}
  	close(F);
    return;
}

#it expects three arguments, otherwise returns undef
#it returns a full patch <dir>/<filename>
sub get_temp_filename {
    my($self, $template,$directory,$suffix)=@_;
    	$self->log->debug("template: <$template> directory: <$directory> suffix: <$suffix> ");
	if (! defined $template || ! defined $directory || ! defined $suffix) {
		$self->log->debug("some variable missing, please check ");
		return;
	}			
    my $fh = File::Temp->new(
        TEMPLATE => $template,
        DIR      => $directory,
        SUFFIX   => $suffix,
        UNLINK   => 1,
    );

	#it returns a full patch <dir>/<filename>
    return $fh->filename;
}

1;
