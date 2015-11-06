use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::Network');

use DBOD::Network;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::MockModule;

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

my $network = Test::MockModule->new('DBOD::Network');
$network->mock( _get_landb_connection => sub { return ($client, $auth);} );


subtest 'add_ip_alias' => sub {
    $call->set_false('fault');
    is(DBOD::Network::add_ip_alias('db-dbod-000','dbod-test', \%config), 0, 'add_ip_alias OK');

    $call->set_true('fault');
    is(DBOD::Network::add_ip_alias('db-dbod-000','dbod-test', \%config), 1, 'add_ip_alias FAIL');
};

subtest 'remove_ip_alias' => sub {
    $call->set_false('fault');
    is(DBOD::Network::remove_ip_alias('db-dbod-000','dbod-test', \%config), 0, 'remove_ip_alias OK');

    $call->set_true('fault');
    is(DBOD::Network::remove_ip_alias('db-dbod-000','dbod-test', \%config), 1, 'remove_ip_alias FAIL');
};

subtest 'get_ip_alias' => sub {
    $call->set_false('fault');
    $call->mock('result', sub { return 'dbod-test' });
    is(DBOD::Network::get_ip_alias('db-dbod-000','dbod-test', \%config), 'dbod-test', 'get_ip_alias OK');

    $call->set_true('fault');
    $call->mock('result', sub { return undef });
    is(DBOD::Network::get_ip_alias('db-dbod-000','dbod-test', \%config), undef, 'get_ip_alias FAIL');
};


subtest 'create_ip_alias' => sub {

    my $api = Test::MockModule->new('DBOD::Api');
    my %result = ( response => ['db-dbod-000', 'dbod-test'] ); 
    $api->mock('set_ip_alias', sub { return \%result; });
    
    my $rt = Test::MockObject->new();
    my $runtime = Test::MockModule->new('DBOD::Runtime');
    $runtime->mock('new', sub {return $rt;});

    my %ipalias = ( change_command => '/path/to/command' );
    $config{ipalias} = \%ipalias;
    my %input = ( hosts => ['hostname'], ip_alias => 'dbod-test', dbname => 'test' );
    
    $rt->mock('run_cmd', sub { return 0 });
    ok(DBOD::Network::create_alias(\%input, \%config), 'create_alias OK');
    
    $rt->mock('run_cmd', sub { return 1 });
    ok(DBOD::Network::create_alias(\%input, \%config), 'create_alias FAIL');

};

done_testing();
