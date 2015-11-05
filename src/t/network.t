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

# First we test the _get_landb_connection method mocking
# its internal SOAP::Lite calls

subtest '_get_landb_connection' => sub {

    use SOAP::Lite;
    my $soap = Test::MockObject::Extends->new(SOAP::Lite->new());
    my $soap_client = Test::MockObject->new();
    my $soap_call = Test::MockObject->new();
    $soap_client->mock('getAuthToken', sub {return $soap_call;});
    $soap->mock('new', sub { return $soap_client; });
    
    my $soap_header = Test::MockModule->new('SOAP::Lite');
    $soap_header->mock('name', sub {return Test::MockModule->new();});
    

    $soap_call->set_false('fault');
    $soap_call->mock('result', sub {return Test::MockObject->new();});
    my ($client, $auth) = DBOD::Network::_get_landb_connection(\%config);
    note Dumper $client;
    note Dumper $auth;
    #like($client, qr/Test::MockObject/, 'Returns object (client)');
    #like($auth, qr/Test::MockObject/, 'Returns object (auth)');
    
    $soap_call->set_true('fault');
    ($client, $auth) = DBOD::Network::_get_landb_connection(\%config);
    note Dumper $client;
    note Dumper $auth;
    is(DBOD::Network::_get_landb_connection(\%config), undef, 'No SOAP connection');

};

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


    pass();
};

done_testing();
