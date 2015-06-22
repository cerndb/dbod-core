# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Runtime;

use strict;
use warnings;

use Moose;
with 'MooseX::Log::Log4perl';

use Try::Tiny;
use IPC::Run qw(run timeout);
use Net::OpenSSH;
use Data::Dumper;

sub run_cmd {
    my ($self, $cmd_str, $timeout) = @_;
    my @cmd = split ' ', $cmd_str ;
    try {
        my ($out, $err);
        if (defined $timeout) {
            $self->log->debug("Executing ${cmd_str} with timeout: ${timeout}");
            run \@cmd, ,'>', \$out, '2>', \$err, (my $t = timeout $timeout);
        }
        else {
            $self->log->debug("Executing ${cmd_str}");
            run \@cmd, ,'>', \$out, '2>', \$err;
        }
        # If the command executed succesfully we return its exit code
        $self->log->debug("${cmd_str} return code: " . $?);
        return scalar $?;
    } 
    catch {
        if ($_ =~ /^IPC::Run: .*timeout/) {
            # Timeout exception
            $self->log->error("Timeout exception: " . $_);
            return;
        }
        else {
            # Other type of exception ocurred
            $self->log->error("Exception found: " . $_);
            return;
        }
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

# Method to implement a timeout while checking a condition.
# Condition should be implemented by a routine
sub TimeoutOneparam {
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

sub RunStr {   
	my($self, $cmd,$str,$fake,$text) = @_; 
	$self->log->info("Parameters cmd: not displayed, fake: <$fake>, text: <$text>");
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


sub GetIPFromCName {     
	my($self, $name) = @_; 
	$self->log->info("Parameters name: <$name>");

	my (@output,$rc);
	my $cmd="ping -c 1 $name";

	$rc=$self->RunStr($cmd,\@output);

	if ($rc) {
		foreach (@output) {
			if (/PING .*? \((\d+\.\d+\.\d+\.\d+)\) /) {
				$self->log->debug("IP <$1> for <$name>");
				return $1;
			}
		}
	} else {
		$self->log->debug("Problem retrieving IP from <$name>: @output");
		return 0;
	}
	return 0; 
}

sub RetrievePasswordForUser {  
	my($self,$user) =@_;
	my($password);
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
	return undef;
 
}

sub GetVersionDB {         
	my($self,$file)=@_;
	$self->log->info("Parameters file: <$file>");
	if (-e "$file") {
		my(@arr)=$self->ReadFile("$file"); 
		if (scalar(@arr) ==0 ) {
			$self->log->error("File <$file>  is empty. Strange.");
			return undef;
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
	return undef;
}

#Returns 1 if the instanc is CRS, 0 otherwise
#sub IsInstanceCRS {
#	my($self,$job) = @_;
#	$self->log->info("Parameters job: not displayed");
#
#	if (defined $job->metadata->{'crs_ref'}) {
#		$self->log->debug($job->entity . ' is managed by CRS' );
#		return 1; 
#	} else {
#		$self->log->debug($job->entity . ' is NOT managed by CRS' );
#		return 0; 
#	}
#} 


#Returns the state of a CRS resource (if the state is undef CRS is not installed or the resource does not exist)
sub GetCRSResourceState {
	my($self,$resource, $oracle_crs)=@_; 
	my($rc,@output,$state);
	$self->log->info("Parameters resource: <$resource> oracle_crs: <$oracle_crs>");


	$rc = $self->RunStr("$oracle_crs status resource $resource | grep STATE | awk -F\"=\" '{print \$2}' | awk '{print \$1}'", \@output);
	if ($rc) {	
		$state = $output[0];
		if (defined $state) {
			chomp $state;
		}
		$self->log->debug("Resource is in <$state>");
		return $state;
	}
	else {
		$self->log->debug("Error getting CRS resource state!");
		return undef;
	}
}

#Starts a CRS resource 
sub StartCRSResource {
        my ($self,$resource,$oracle_crs) = @_;
        my ($cmd, $rc, @output);
	 $self->log->info("Parameters resource: <$resource> oracle_crs: <$oracle_crs>");

        $self->log->debug("Checking CRS resource state.");
        my ($state) = $self->GetCRSResourceState($resource, $oracle_crs);
        if (defined $state) {
                #If instance is CRS and UNKNOWN
                if ($state eq "UNKNOWN") {
                        $self->log->error("The instance is in UNKNOWN state! Please check.");
                        return 0; #not ok
                }
                #If instance is CRS and INTERMEDIATE
                if ($state eq "INTERMEDIATE") {
                        $self->log->error("The instance is in INTERMEDIATE state! Please check.");
                        return 0; #Not ok
                }
                #If instance is CRS and ONLINE
                if ($state eq "ONLINE") {
                        $self->log->debug("The instance was running. Nothing to do.");
                        return 1; #ok
                }
                #If instance is CRS adn OFFLINE
                if ($state eq "OFFLINE") {
                        $cmd = "$oracle_crs start resource $resource";
                        $rc = $self->RunStr($cmd, \@output);
                        $self->log->debug(join("",@output));
                        if ($rc) {
                                $self->log->debug("CRS resource is up");
                                return 1; #ok
                        } else {
                                $self->log->error("Problem starting CRS resource. Please check.");
                                return 0; #notok
                        }
                }
                $self->log->error("CRS state $state is not a valid state.");
                return 0; #not ok
        }
        else {
                $self->log->error("StartCRSResource: Given CRS resource was not found. Please check.");
                return 0; #not ok
        }
} 

#Stops a CRS resource
sub StopCRSResource { 
        my ($self,$resource, $oracle_crs) = @_;
	 $self->log->info("Parameters resource: <$resource> oracle_crs: <$oracle_crs>");

        my ($cmd, $rc, @output);
        $self->log->error("Checking CRS resource state.");
        my ($state) = &GetCRSResourceState($resource, $oracle_crs);
        if (defined $state) {
                #If instance is CRS and UNKNOWN
                if ($state eq "UNKNOWN") {
                        $self->log->error("The instance is in UNKNOWN state! Please check.");
                        return 0; #notok
                }
                #If instance is CRS and INTERMEDIATE
                if ($state eq "INTERMEDIATE") {
                        $self->log->error("The instance is in INTERMEDIATE state! Please check.");
                        return 0; #notok
                }
                #If instance is CRS and OFFLINE 
                if ($state eq "OFFLINE") {
                        $self->log->error("The instance was not running. Nothing to do.");
                        return 1; #ok
                }
                #If instance is CRS adn ONLINE
                if ($state eq "ONLINE") {
                        $cmd = "$oracle_crs stop resource $resource";
                        $rc = $self->RunStr($cmd, \@output);
                        $self->log->debug(join("",@output));
                        if ($rc) {
                                $self->log->debug("MySQL instance is down");
                                return 1; #ok
                        } else {
                                $self->log->error("Problem stopping MySQL instance. Please check.");
                                return 0; #notok
                        }
                }
                $self->log->error("CRS state $state is not a valid state.");
                return 0; #notok
        }
        else {
                $self->log->error("Given CRS resource was not found. Please check.");
                return 0; #notok
        }
}




sub Read_Directory {
	my($self,$dir,$pattern)=@_;
	$self->log->info("Parameters dir: <$dir> pattern: <$pattern>");

	my(@files);

	opendir (D,$dir) || $self->log->debug("Cannot read directory $dir : $!");
	if (defined $pattern) {
		@files=grep(/$pattern/,readdir(D));
	} else {
		@files=grep(!/^\.\.?$/,readdir(D));
	}
	closedir(D);
 
	return @files;
} 

sub ReadFile {
	my($self,$file)=@_;
	$self->log->info("Parameters file: <$file>");

	open(F,$file) || $self->log->error("Cant read file $file. Error: $! ");
	my(@text) = <F>;
	close(F);
	return @text;
}

sub CheckFile {
	my($self,$file,$check)=@_;
	my($flag)=0;
	if (! defined $check) {
		$check="e";
	}
	if ($check eq 'e') {
		if (-e $file) {
			$flag=1;
		}
	} elsif ($check eq 'r') {
		if (-r $file) {
			$flag=1;
		}

	} elsif ($check eq 'w') {
		if (-w $file) {
			$flag=1;
		}
	} elsif ($check eq 'x') {
		if (-x $file) {
			$flag=1;
		}
	}
	if ($flag) {
		$self->log->debug("<$check> true on file <$file>");
		return 1; #ok
	} else {
		return 0; 
	}


}