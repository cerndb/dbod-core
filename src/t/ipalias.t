use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::IPalias');

use Test::MockObject;
use Test::MockModule;
use Test::MockObject::Extends;

# We need to Mock the _api_client method on the
# DBOD::Api module

# We create the class mocking the _api_client return object
my $rest_client = Test::MockObject->new();
$rest_client->set_true('addHeader');
$rest_client->set_true('getUseragent');
$rest_client->set_true('buildQuery');
$rest_client->mock('GET');
$rest_client->mock('PUT');
$rest_client->mock('POST');
$rest_client->mock('DELETE');

my %result = ( response => ['db-dbod-000', 'dbod-test'] ); 
my $api_m = Test::MockModule->new('DBOD::Api');
$api_m->mock( get_ip_alias => sub {return \%result} );
$api_m->mock( set_ip_alias => sub {return \%result} );

# For testing the rest of the methods we mock the _get_landb_connection method
my $auth = Test::MockObject->new();
my $call = Test::MockObject->new();
$call->set_false('fault');
$call->mock('faultstring', sub { return "SOAP call error"; } );

my $client = Test::MockObject->new();
$client->mock('dnsDelegatedAliasAdd', sub {return $call;} );
$client->mock('dnsDelegatedAliasRemove', sub {return $call;} );
$client->mock('dnsDelegatedAliasSearch', sub {return $call;} );

my $network = Test::MockModule->new('DBOD::Network');
$network->mock( _get_landb_connection => sub { return ($client, $auth);} );

my $share_dir = File::ShareDir::dist_dir('DBOD');
my %config = ();
my %api = ();
$api{'cachefile'} = "$share_dir/test.json";
$api{'host'} = "https://api-server:443";
$api{'timeout'} = "3";
$api{'user'} = "API-USER";
$api{'password'} = "XXXXXXXXX";
$api{'entity_metadata_endpoint'} = "api/v1/entity";
$api{'entity_ipalias_endpoint'} = "api/v1/entity/alias";

my %ipalias = ( change_command => '/path/to/command' ); 
$config{'api'} = \%api;
$config{'common'} = { template_folder => "${share_dir}/templates" };
$config{'ipalias'} = \%ipalias;

my $rt = Test::MockObject->new();
my $runtime = Test::MockModule->new('DBOD::Runtime');
$runtime->mock('new', sub {return $rt;});

subtest 'add_alias' => sub { 
    
    $rt->mock('run_cmd', sub { return 0 });
    is(DBOD::IPalias::add_alias('test', 'dbod-test', \%config), 1, 'Registered alias');

    $rt->mock('run_cmd', sub { return 1 });
    is(DBOD::IPalias::add_alias('test', 'dbod-test', \%config), 0, 'External failure: change_command');

    $api_m->mock( get_ip_alias => sub {return undef} );
    is(DBOD::IPalias::add_alias('test', 'dbod-test', \%config), 0, 'API Failure');

};

subtest 'remove_alias' => sub { 

    $api_m->mock( get_ip_alias => sub {return \%result} );
    $rt->mock('run_cmd', sub { return 0 });
    is(DBOD::IPalias::remove_alias('test', 'hostname', \%config), 1, 'Removed alias');
    
    $rt->mock('run_cmd', sub { return 1 });
    is(DBOD::IPalias::remove_alias('test', 'hostname', \%config), 0, 'External failure: change_command');
    
    $api_m->mock( get_ip_alias => sub {return undef} );
    is(DBOD::IPalias::remove_alias('test', 'dbod-test', \%config), 0, 'API Failure');

};


done_testing();
