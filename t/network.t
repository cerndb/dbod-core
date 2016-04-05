use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::Network::LanDB');

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

use Test::MockObject;
use Test::MockObject::Extends;
use Test::MockModule;

use DBOD;

my %network = ( username => 'USER', password => 'PASSWD' );
my %config = ();
$config{network} = \%network;

# For testing the rest of the methods we mock the _get_landb_connection method

my $auth = Test::MockObject->new();
my $call = Test::MockObject->new();
$call->mock('faultstring', sub { return "SOAP call error"; } );

my $client = Test::MockObject->new();
$client->mock('dnsDelegatedAliasAdd', sub {return $call;} );
$client->mock('dnsDelegatedAliasRemove', sub {return $call;} );
$client->mock('dnsDelegatedAliasSearch', sub {return $call;} );

my $network = Test::MockModule->new('DBOD::Network::LanDB');
$network->mock( _get_landb_connection => sub { return ($client, $auth);} );


subtest 'add_ip_alias' => sub {
    $call->set_false('fault');
    is(DBOD::Network::LanDB::add_ip_alias('db-dbod-000','dbod-test', \%config),
        $OK, 'add_ip_alias OK');

    $call->set_true('fault');
    is(DBOD::Network::LanDB::add_ip_alias('db-dbod-000','dbod-test', \%config),
        $ERROR, 'add_ip_alias FAIL');
};

subtest 'remove_ip_alias' => sub {
    $call->set_false('fault');
    is(DBOD::Network::LanDB::remove_ip_alias('db-dbod-000','dbod-test', \%config),
        $OK, 'remove_ip_alias OK');

    $call->set_true('fault');
    is(DBOD::Network::LanDB::remove_ip_alias('db-dbod-000','dbod-test', \%config),
        $ERROR, 'remove_ip_alias FAIL');
};

subtest 'get_ip_alias' => sub {
    $call->set_false('fault');
    $call->mock('result', sub { return 'dbod-test' });
    is(DBOD::Network::LanDB::get_ip_alias('db-dbod-000','dbod-test', \%config), 'dbod-test', 'get_ip_alias OK');

    $call->set_true('fault');
    $call->mock('result', sub { return undef });
    is(DBOD::Network::LanDB::get_ip_alias('db-dbod-000','dbod-test', \%config), undef, 'get_ip_alias FAIL');
};


subtest 'create_ip_alias' => sub {

    my $api = Test::MockModule->new('DBOD::Network::Api');
    my %result = ( response => ['db-dbod-000', 'dbod-test'] ); 
    $api->mock('set_ip_alias', sub { return \%result; });
    
    my $runtime = Test::MockModule->new('DBOD::Runtime');

    my %ipalias = ( change_command => '/path/to/command' );
    $config{ipalias} = \%ipalias;
    my %input = ( hosts => ['hostname'], ip_alias => 'dbod-test', dbname => 'test' );
    
    $runtime->mock('run_cmd', sub {return $OK;});
    $call->set_false('fault');
    is(DBOD::Network::LanDB::create_alias(\%input, \%config),
        $OK, 'create_alias OK');

    $call->set_true('fault');
    is(DBOD::Network::LanDB::create_alias(\%input, \%config),
        $ERROR, 'create_alias FAIL at LANDB API');

    $runtime->mock('run_cmd', sub {return $ERROR;});
    is(DBOD::Network::LanDB::create_alias(\%input, \%config),
        $ERROR, 'create_alias FAIL at dnsname change');



};

done_testing();
