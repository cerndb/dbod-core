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
    };
    return;
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

#Parses mysql error file after a certain string
sub parse_err_file {
    my ($self, $cad, $file) = @_;
    my $start = int(`grep \"$cad\" $file --line-number |tail -n1 |cut -d\":\" -f1`);
    my $total = int(`wc -l $file|cut -d\" \" -f1`);
    my $lines = $total - $start + 1;
    my $res = `tail $file -n $lines`;
    return $res;
}

sub RunStr {   
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


sub GetIPFromCName {     
	my($self, $name) = @_; 
	$self->log->info("Parameters name: <$name>");

	my (@output,$rc);
	my $cmd="ping -c 1 $name";

	$rc=$self->RunStr($cmd,\@output);

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
	return;
 
}

sub GetVersionDB {         
	my($self,$file)=@_;
	$self->log->info("Parameters file: <$file>");
	if (-e "$file") {
		my(@arr)=$self->ReadFile("$file"); 
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
		return;
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

sub EnableAppDynamics {
	my($self,$servername,$connectionstring,$username,$password,$dbtype,$drivername,$hostname,$dbport,$loggingenabled,$collectorport,$sysdba,$osusername,$ospassword,$collectos,$ostype,$oshostname,$osport,$aeskey,$appdhost,$appdport,$appduser,$appdpassword) = @_;	
	my $this=(caller(0))[3];

	#build $dsn
	if (! defined $appdhost || ! defined $appdport || ! defined $appduser || ! defined $appdpassword) {
		$self->log->error("Some variables are missing appdhost: <$appdhost>  appdort: <$appdport> appduser: <$appduser>  appdpassword may be empty"); 
		return 0; # error
	}
	$self->log->info("Parameters servername: <$servername> connectionstring: <$connectionstring> username: <$username> password: <not displayed> dbtype: <$dbtype> drivername: <$drivername> hostname: <$hostname> dbport: <$dbport> collectorport: <$collectorport>");
	#dbtuna is the appsdyamics database
	my $dsn = "DBI:mysql:database=dbtuna;host=$appdhost;port=$appdport"; 
	my $dbh = DBI->connect($dsn, $appduser, $appdpassword,  {RaiseError => 0, AutoCommit => 1} ) or LoggerActions::Log("$this: Couldn't connect to database: " . DBI->errstr);

	#For extra debugging enable this
	#DBI->trace(4); 
 
	if (! defined $dbh) {
		$self->log->error("Couldn't connect to database: <$dsn>");
		return 0;
	}

	if (! defined $servername || ! defined $connectionstring || ! defined $username || ! defined $password || ! defined $dbtype || ! defined $drivername || ! defined $hostname || ! defined $dbport || ! defined $loggingenabled || ! defined $collectorport || ! defined $sysdba) {
		$self->log->error("Some variable not defined: servername <$servername>, connectionstring <$connectionstring>, username <$username>, password: XXX dbtype <$dbtype> drivername <$drivername> hostname <$hostname> dbport <$dbport> loggingenabled <$loggingenabled> collectorport <$collectorport> sysdba <$sysdba>");
		return 0; # error
	}

	if (! defined $osusername || ! defined $ospassword || ! defined $collectos || ! defined $ostype || ! defined $oshostname || ! defined $osport || ! defined $aeskey) {
		$self->log->error("Some variable not defined: osusername <$osusername> ospassword <$ospassword> collectos <$collectos> ostype <$ostype> oshotsname <$oshostname> osport <$osport> aeskey <aeskey> ");
		return 0; # error
	}
	
	$servername=lc $servername;
	$dbtype = uc $dbtype;
	$ostype = uc $ostype; 
	my $sth; 
	eval {
		if ($osusername eq 'NULL') {
			$sth = $dbh->prepare("INSERT INTO monitoredservers
		                (servername,connectionstring,username,password,dbtype,drivername,hostname,dbport,loggingenabled,collectorport,sysdba,osusername,ospassword,collectos,ostype,oshostname,osport)
       	                 values
              	         ('$servername','$connectionstring','$username',AES_ENCRYPT('$password','$aeskey'),'$dbtype','$drivername','$hostname','$dbport','$loggingenabled','$collectorport','$sysdba',NULL,NULL,'$collectos','$ostype','$oshostname','$osport')");
			
		} else {
			$sth = $dbh->prepare("INSERT INTO monitoredservers
		                (servername,connectionstring,username,password,dbtype,drivername,hostname,dbport,loggingenabled,collectorport,sysdba,osusername,ospassword,collectos,ostype,oshostname,osport)
              	          values
                     	  ('$servername','$connectionstring','$username',AES_ENCRYPT('$password','$aeskey'),'$dbtype','$drivername','$hostname','$dbport','$loggingenabled','$collectorport','$sysdba','$osusername',AES_ENCRYPT('$ospassword','$aeskey'),'$collectos','$ostype','$oshostname','$osport')");
		}
	
		$sth->execute() or $self->log->error("Some error while running INSERT: " . $DBI::errstr);
		$sth->finish();
		$dbh->disconnect or $self->log->error("Some error closing connection: " . $DBI::errstr); 
	}; 
	if ($@) {
		$self->log->error("Error while inserting:" . $sth->errstr);
		return 0; #some error
	} else {
		return 1; #ok
	}
} 

sub IsAppDynamicsEnabled {
	my($self,$servername,$appdhost,$appdport,$appduser,$appdpassword) = @_;	
	$self->log->info("Parameters servername: <$servername> appdhost: <$appdhost> appduser: <$appduser> appdpassword: <not displayed> appdort: <$appdport>");

	if (! defined $appdhost || ! defined $appdport || ! defined $appduser || ! defined $appdpassword) {
		$self->log->error("some variables are missing appdhost: <$appdhost>  appdort: <$appdport> appduser: <$appduser>  appdpassword may be empty"); 
		return 0; # error
	}

	
	my $dsn = "DBI:mysql:database=dbtuna;host=$appdhost;port=$appdport"; 
	my $dbh = DBI->connect($dsn, $appduser, $appdpassword ) or $self->log->error("Couldn't connect to database: " . DBI->errstr);

	if (! defined $dbh) {
		$self->log->error("Couldn't connect to database: <$dsn>");
		return 0;
	}

	$servername = lc $servername;
	my $sth = $dbh->prepare("select 1 from monitoredservers where servername=?");
	$sth->execute( $servername ) or $self->log->error("Error running query: " . $DBI::errstr);
	my $rows= $sth->rows;
	if ($rows == 1) {
		$self->log->debug("<$servername> is already defined");
		$sth->finish();
		$dbh->disconnect;	
		return 1; #ok
	} else {
		$self->log->error("<$servername> is found <$rows> not equal to 1");
		$sth->finish();
		$dbh->disconnect;	
		return 0; #error 
		
	}
	
}


sub DisableAppDynamics {
	my($self,$servername,$appdhost,$appdport,$appduser,$appdpassword) = @_;	
	$self->log->info("Parameters servername: <$servername> appdhost: <$appdhost> appduser: <$appduser> appdpassword: <not displayed> appdort: <$appdport>");
	
	if (! defined $appdhost || ! defined $appdport || ! defined $appduser || ! defined $appdpassword) {
		$self->log->debug("some variables are missing appdhost: <$appdhost>  appdort: <$appdport> appduser: <$appduser>  appdpassword may be empty"); 
		return 0; # error
	} 

	
	my $dsn = "DBI:mysql:database=dbtuna;host=$appdhost;port=$appdport"; 
	my $dbh = DBI->connect($dsn, $appduser, $appdpassword ) or $self->log->error("Couldn't connect to database: " . DBI->errstr);

	if (! defined $dbh) {
		$self->log->error("Couldn't connect to database: <$dsn>");
		return 0;
	}

	$servername = lc $servername;
	eval {
		my $sth = $dbh->prepare("DELETE FROM monitoredservers WHERE servername=?");
		$sth->execute( $servername ) or $self->log->error("Couldn't delete from database <$servername> : " . DBI->errstr);
		$sth->finish();
	};

	if ($@) {
		$self->log->error("Couldnt delete <$servername>");
		return 0; # error 
	}
	return 1; # ok
}

 
#it gets an alias and it validates via ping
sub GetAliasFromEntity {
	my($self,$entity)=@_;
	$self->log->info("Retrieving alias for <$entity>");

	$entity =~ s/dod_/dbod-/;  
	$entity =~ s/_/-/g;

	$self->log->debug("Possible alias is <$entity>.");
	my $rc = $self->GetIPFromCName($entity);
	if ($rc eq "0") {
			$self->log->debug("Problem retrieving IP from <$entity>. Ping didnt work. Strange!");
	} else {
		return $entity;
	}	 	
	return 0;
	
}


sub Read_Directory {
	my($self,$dir,$pattern)=@_;
	$self->log->info("Parameters dir: <$dir> pattern: <$pattern>");

	my(@files);

	opendir (D,$dir) || $self->log->debug("Cannot read directory $dir : $!");
	if (defined $pattern) {
		@files = grep {/$pattern/} readdir(D);
	} else {
        @files = grep {!/^\.\.?$/} readdir(D);
	}
	closedir(D);
 
	return @files;
} 

sub ReadFile {
	my($self,$file)=@_;
	$self->log->info("Parameters file: <$file>");

	open my $F, '<', $file || $self->log->error("Cant read file $file. Error: $! ");
	my(@text) = <$F>;
	close($F);
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

1;
