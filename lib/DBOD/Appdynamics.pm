package DBOD::Appdynamics;
use strict;
use warnings FATAL => 'all';

use Log::Log4perl qw(:easy);

use Socket;

use DBOD::DB;

sub enable {

    my ($servername, $connectionstring, $username, $password,
        $dbtype, $drivername, $hostname, $dbport, $loggingenabled,
        $collectorport, $sysdba, $osusername, $ospassword, $collectos,
        $ostype, $oshostname, $osport, $aeskey,
        $appdhost, $appdport, $appduser, $appdpassword) = @_;

    #build $dsn
    if (! defined $appdhost || ! defined $appdport || ! defined $appduser || ! defined $appdpassword) {
        ERROR "Appdynamic related argument missing ";
        return 0; # error
    }
    if (! defined $servername || ! defined $connectionstring || ! defined $username
        || ! defined $password || ! defined $dbtype || ! defined $drivername
        || ! defined $hostname || ! defined $dbport || ! defined $loggingenabled
        || ! defined $collectorport || ! defined $sysdba) {
        ERROR "Instance related argument missing ";
        return 0; # error
    }

    if (! defined $osusername || ! defined $ospassword || ! defined $collectos
        || ! defined $ostype || ! defined $oshostname || ! defined $osport || ! defined $aeskey) {
        ERROR "OS related argument missing";
        return 0; # error
    }

    # DB Connection Object
    my $dsn = "DBI:mysql:database=dbtuna;host=$appdhost;port=$appdport";

    my $db = DBOD::DB->new(
        db_dsn  => $dsn,
        db_user => $appduser,
        db_password => $appdpassword,
        db_attrs => {RaiseError => 0, Autocommit => 1},
    );

    $servername = lc $servername;
    $dbtype = uc $dbtype;
    $ostype = uc $ostype;

    my $affected_rows;
    if ($osusername eq 'NULL') {
        my @bind_values = ($servername, $connectionstring,
            $username, $password, $aeskey,
            $dbtype, $drivername,$hostname, $dbport,
            $loggingenabled, $collectorport, $sysdba,
            undef, undef, $collectos, $ostype, $oshostname, $osport);
        $affected_rows = $db->do("INSERT INTO monitoredservers
            (servername,connectionstring,username,password,dbtype,
            drivername,hostname,dbport,loggingenabled,collectorport,
            sysdba,osusername,ospassword,collectos,ostype,oshostname,osport)
             values (?,?,?,AES_ENCRYPT(?,?),?,?,?,?,?,?,?,?,?,?,?,?,?)", \@bind_values);

    } else {
        my @bind_values = ($servername, $connectionstring,
            $username, $password, $aeskey, $dbtype, $drivername,
            $hostname, $dbport, $loggingenabled, $collectorport,
            $sysdba, $osusername, $ospassword, $aeskey, $collectos,
            $ostype, $oshostname, $osport);
        $affected_rows = $db->do("INSERT INTO monitoredservers
            (servername,connectionstring,username,password,dbtype,
            drivername,hostname,dbport,loggingenabled,collectorport,
            sysdba,osusername,ospassword,collectos,ostype,oshostname,osport)
              values
              (?,?,?,AES_ENCRYPT(?,?),?,?,?,?,?,?,?,?,AES_ENCRYPT(?, ?),?,?,?,?)", \@bind_values);
    }

    if ($affected_rows != 1) {
        return 0; #some error
    } else {
        return 1; #ok
    }
}

sub is_enabled {
    my ($servername, $config) = @_;
    my $host = $config->{host};
    my $port = $config->{port};
    my $user = $config->{user};
    my $password = $config->{password};

    my $dsn = "DBI:mysql:database=dbtuna;host=$host;port=$port";
    my $db = DBOD::DB->new(
        db_dsn  => $dsn,
        db_user => $user,
        db_password => $password,
        db_attrs => {RaiseError => 0, Autocommit => 1},
    );

    $servername = lc $servername;
    my @bind_params = ($servername);
    my $rows = $db->do("select 1 from monitoredservers where servername=?", \@bind_params);
    if ($rows == 1) {
        INFO "<$servername> is already defined";
        return 1; #ok
    } else {
        ERROR "<$servername> is found <$rows> not enabled";
        return 0; #error
    }

}

sub disable {
    my ($servername, $config) = @_;
    my $host = $config->{host};
    my $port = $config->{port};
    my $user = $config->{user};
    my $password = $config->{password};

    my $dsn = "DBI:mysql:database=dbtuna;host=$host;port=$port";
    my $db = DBOD::DB->new(
        db_dsn  => $dsn,
        db_user => $user,
        db_password => $password,
        db_attrs => {RaiseError => 0, Autocommit => 1},
    );

    $servername = lc $servername;
    my @bind_params = ($servername);
    my $rows = $db->do("DELETE FROM monitoredservers WHERE servername=?", \@bind_params);
    if ($rows != 1) {
        ERROR "Couldnt delete <$servername>";
        return 0; # error
    }
    return 1; # ok
}

# TODO: Is this method actually required if aliases follow convention?
sub get_alias_from_entity {
    my $entity = shift;
    INFO "Retrieving alias for <$entity>";
    $entity =~ s/dod_/dbod-/;
    $entity =~ s/_/-/g;
    DEBUG "Possible alias is <$entity>.";
    my $rc = inet_ntoa(inet_aton($entity));
    if ($rc eq "0") {
        DEBUG "Problem retrieving IP from <$entity>. Ping didnt work. Strange!";
    } else {
        return $entity;
    }
    return 0;
}

1;