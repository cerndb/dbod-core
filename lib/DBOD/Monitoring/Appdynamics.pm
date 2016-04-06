package DBOD::Monitoring::Appdynamics;
use strict;
use warnings FATAL => 'all';

use Log::Log4perl qw(:easy);

use Socket;

use DBOD::DB;

sub enable {

    my ($servername, $config, $metadata) = @_;

    my $connectionstring; # depends on type
    my $username;
    my $password;
    my $drivername;

    # Argument unpacking
    my $hostname = $metadata->{host}[0]; # Functional alias
    my $dbport = $metadata->{port};
    my $dbtype = lc $metadata->{subcategory};
    $username = $config->{$dbtype}->{db_user};
    $password = $config->{$dbtype}->{db_password};

    # TODO: Set drivername in config file
    if ($dbtype eq 'mysql'){
        $connectionstring = "jdbc:mysql://${hostname}:${dbport}/";
        $drivername = "org.gjt.mm.mysql.Driver";
    }
    else {
        $connectionstring = "jdbc:postgresql://${hostname}:${dbport}/";
        $drivername = "org.postgresql.Driver";
    }
    # TODO: Do something with this magic constants?;
    my $loggingenabled = 0;
    my $collectorport = 0;
    my $sysdba = 0;
    my $osusername = 'NULL';
    my $ospassword = 'NULL';
    my $collectos = 'N';
    my $ostype = 'LINUX';
    my $oshostname = $metadata->{host}[0]; # Functional_alias
    my $osport = 22;
    my $aeskey = $config->{appdynamics}->{aeskey};
    my $appdhost = $config->{appdynamics}->{host};
    my $appdport = $config->{appdynamics}->{port};
    my $appduser = $config->{appdynamics}->{user};
    my $appdpassword = $config->{appdynamics}->{password};

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

    } else { # TODO: Is this use case still needed?
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
sub get_active_alias {
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