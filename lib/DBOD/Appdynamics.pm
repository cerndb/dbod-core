package DBOD::Appdynamics;
use strict;
use warnings FATAL => 'all';

sub enable {

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

sub is_enabled {
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

sub disable {
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




1;