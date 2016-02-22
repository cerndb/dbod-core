package DBOD::Appdynamics;
use strict;
use warnings FATAL => 'all';

use Log::Log4perl qw(:easy);

sub enable {

    my($self,$servername,$connectionstring,$username,$password,$dbtype,$drivername,$hostname,$dbport,$loggingenabled,$collectorport,$sysdba,$osusername,$ospassword,$collectos,$ostype,$oshostname,$osport,$aeskey,$appdhost,$appdport,$appduser,$appdpassword) = @_;
    my $this=(caller(0))[3];

    #build $dsn
    if (! defined $appdhost || ! defined $appdport || ! defined $appduser || ! defined $appdpassword) {
        ERROR "Some variables are missing appdhost: <$appdhost>  appdort: <$appdport> appduser: <$appduser>  appdpassword may be empty";
        return 0; # error
    }
    INFO "Parameters servername: <$servername> connectionstring: <$connectionstring> username: <$username> password: <not displayed> dbtype: <$dbtype> drivername: <$drivername> hostname: <$hostname> dbport: <$dbport> collectorport: <$collectorport>";
    #dbtuna is the appsdyamics database
    my $dsn = "DBI:mysql:database=dbtuna;host=$appdhost;port=$appdport";
    my $dbh = DBI->connect($dsn, $appduser, $appdpassword,  {RaiseError => 0, AutoCommit => 1} ) or ERROR "$this: Couldn't connect to database: " . DBI->errstr;

    #For extra debugging enable this
    #DBI->trace(4);

    if (! defined $dbh) {
        ERROR "Couldn't connect to database: <$dsn>";
        return 0;
    }

    if (! defined $servername || ! defined $connectionstring || ! defined $username || ! defined $password || ! defined $dbtype || ! defined $drivername || ! defined $hostname || ! defined $dbport || ! defined $loggingenabled || ! defined $collectorport || ! defined $sysdba) {
        ERROR "Some variable not defined: servername <$servername>, connectionstring <$connectionstring>, username <$username>, password: XXX dbtype <$dbtype> drivername <$drivername> hostname <$hostname> dbport <$dbport> loggingenabled <$loggingenabled> collectorport <$collectorport> sysdba <$sysdba>";
        return 0; # error
    }

    if (! defined $osusername || ! defined $ospassword || ! defined $collectos || ! defined $ostype || ! defined $oshostname || ! defined $osport || ! defined $aeskey) {
        ERROR "Some variable not defined: osusername <$osusername> ospassword <$ospassword> collectos <$collectos> ostype <$ostype> oshotsname <$oshostname> osport <$osport> aeskey <aeskey> ";
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

        $sth->execute() or ERROR "Some error while running INSERT: " . $DBI::errstr;
        $sth->finish();
        $dbh->disconnect or ERROR "Some error closing connection: " . $DBI::errstr;
    };
    if ($@) {
        ERROR "Error while inserting:" . $sth->errstr;
        return 0; #some error
    } else {
        return 1; #ok
    }

}

sub is_enabled {
    my($self,$servername,$appdhost,$appdport,$appduser,$appdpassword) = @_;
    INFO "Parameters servername: <$servername> appdhost: <$appdhost> appduser: <$appduser> appdpassword: <not displayed> appdort: <$appdport>";

    if (! defined $appdhost || ! defined $appdport || ! defined $appduser || ! defined $appdpassword) {
        ERROR "some variables are missing appdhost: <$appdhost>  appdort: <$appdport> appduser: <$appduser>  appdpassword may be empty";
        return 0; # error
    }

    my $dsn = "DBI:mysql:database=dbtuna;host=$appdhost;port=$appdport";
    my $dbh = DBI->connect($dsn, $appduser, $appdpassword ) or ERROR "Couldn't connect to database: " . DBI->errstr;

    if (! defined $dbh) {
        ERROR "Couldn't connect to database: <$dsn>";
        return 0;
    }

    $servername = lc $servername;
    my $sth = $dbh->prepare("select 1 from monitoredservers where servername=?");
    $sth->execute( $servername ) or ERROR "Error running query: " . $DBI::errstr;
    my $rows= $sth->rows;
    if ($rows == 1) {
        DEBUG "<$servername> is already defined";
        $sth->finish();
        $dbh->disconnect;
        return 1; #ok
    } else {
        ERROR "<$servername> is found <$rows> not equal to 1";
        $sth->finish();
        $dbh->disconnect;
        return 0; #error
    }

}

sub disable {
    my($self,$servername,$appdhost,$appdport,$appduser,$appdpassword) = @_;
    INFO "Parameters servername: <$servername> appdhost: <$appdhost> appduser: <$appduser> appdpassword: <not displayed> appdort: <$appdport>";

    if (! defined $appdhost || ! defined $appdport || ! defined $appduser || ! defined $appdpassword) {
        DEBUG "some variables are missing appdhost: <$appdhost>  appdort: <$appdport> appduser: <$appduser>  appdpassword may be empty";
        return 0; # error
    }


    my $dsn = "DBI:mysql:database=dbtuna;host=$appdhost;port=$appdport";
    my $dbh = DBI->connect($dsn, $appduser, $appdpassword ) or ERROR "Couldn't connect to database: " . DBI->errstr;

    if (! defined $dbh) {
        ERROR "Couldn't connect to database: <$dsn>";
        return 0;
    }

    $servername = lc $servername;
    eval {
        my $sth = $dbh->prepare("DELETE FROM monitoredservers WHERE servername=?");
        $sth->execute( $servername ) or ERROR "Couldn't delete from database <$servername> : " . DBI->errstr;
        $sth->finish();
    };

    if ($@) {
        ERROR "Couldnt delete <$servername>";
        return 0; # error
    }
    return 1; # ok
}

# TODO: Is this method actually required if aliases follow convention?
sub get_alias_from_entity {
	my($self,$entity)=@_;
	INFO "Retrieving alias for <$entity>";
	$entity =~ s/dod_/dbod-/;
	$entity =~ s/_/-/g;
	DEBUG "Possible alias is <$entity>.";
	my $rc = $self->get_IP_from_cname($entity);
	if ($rc eq "0") {
        DEBUG "Problem retrieving IP from <$entity>. Ping didnt work. Strange!";
	} else {
		return $entity;
	}
	return 0;
}

1;