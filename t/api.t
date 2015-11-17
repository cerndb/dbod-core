use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::Api');

use DBOD::Api;
use Test::MockObject;
use Test::MockModule;

use JSON;

my $share_dir = File::ShareDir::dist_dir('DBOD');
my $filename = "$share_dir/test.json";
my %config = ();
my %api = ();
$api{'cachefile'} = "$share_dir/test.json";
$api{'host'} = "https://api-server:443";
$api{'timeout'} = "3";
$api{'user'} = "API-USER";
$api{'password'} = "XXXXXXXXX";
$api{'entity_metadata_endpoint'} = "api/v1/entity";
$api{'entity_ipalias_endpoint'} = "api/v1/entity/alias";

$config{'api'} = \%api;
$config{'common'} = { template_folder => "${share_dir}/templates" };

# DBOD::Api::load_cache
note( "%config is " . Dumper \%config );
my %cache = DBOD::Api::load_cache(\%config);
note( Dumper \%cache );

isa_ok(\%cache, 'HASH');
ok(exists $cache{'a'});
ok(exists $cache{'c'});
is($cache{'b'}{'prop1'}, 'value1');

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

my $api = Test::MockModule->new('DBOD::Api');
$api->mock( _api_client => $rest_client );

my $entity = 'success';

# DBOD::Api::get_entity_metadata
subtest 'get_entity_metadata' => sub {

    $rest_client->mock('responseCode', sub { return "200" } );
    $rest_client->mock('responseContent', 
        sub { return "{\"metadata\":\"test\"}" } );
    ok(DBOD::Api::get_entity_metadata('unexistant', \%cache, \%config), 
        "Method call");
    my $metadata = DBOD::Api::get_entity_metadata('unexistant', \%cache, 
        \%config);
    isa_ok($metadata, 'HASH', 'Result is a HASH/HASHREF');
    ok(exists $metadata->{metadata}, "Result has metadata field");
    note( Dumper $metadata );
    
    # Test failure
    $rest_client->mock('responseCode', sub { return "404" } );
    $rest_client->mock('responseContent', sub { return "" } );
    ok(DBOD::Api::get_entity_metadata('unexistant', \%cache, \%config), 
        "Method call: error");
    $metadata = DBOD::Api::get_entity_metadata('unexistant', \%cache, \%config);
    isa_ok($metadata, 'HASH', 'Result is a HASH/HASHREF');
    ok(!exists $metadata->{metadata}, "Result has empty metadata field");
};

# DBOD::Api::get_ip_alias
subtest 'get_ip_alias' => sub {

    $rest_client->mock('responseCode', sub { return "200" } );
    $rest_client->mock('responseContent', sub { return "{\"ipalias\":\"dbod-test\"}" } );
    ok(DBOD::Api::get_ip_alias($entity, \%config), "Method call");
    my $result = DBOD::Api::get_ip_alias($entity, \%config);
    note( Dumper $result );
    ok(exists $result->{code}, 'Result has code field');
    ok(exists $result->{response}, 'Result has response field');
    
    # Test failure
    $rest_client->mock('responseCode', sub { return "404" } );
    $rest_client->mock('responseContent', sub { return "" } );
    ok(DBOD::Api::get_ip_alias($entity, \%config), "Method call: error");
    $result = DBOD::Api::get_ip_alias($entity, \%config);
    note( Dumper $result );
    ok(exists $result->{code}, 'Result has code field');
    ok(exists $result->{response}, 'Result has response field');

};

# DBOD::Api::set_ip_alias 
subtest 'set_ip_alias' => sub {

    $rest_client->mock('responseCode', sub { return "201" } );
    $rest_client->mock('responseContent', sub { return "{\"ipalias\":\"dbod-test\"}" } );
    ok(DBOD::Api::set_ip_alias($entity, 'ip-alias',\%config), "set_ip_alias");
    my $result = DBOD::Api::set_ip_alias($entity, 'ip-alias',\%config);
    note( Dumper $result );
    ok(exists $result->{code}, 'Result has code field');
    ok(exists $result->{response}, 'Result has response field');

    # Test failure
    $rest_client->mock('responseCode', sub { return "404" } );
    $rest_client->mock('responseContent', sub { return "" } );
    ok(DBOD::Api::set_ip_alias($entity, 'ip-alias', \%config), "set_ip_alias: error");
    $result = DBOD::Api::set_ip_alias($entity, 'ip-alias', \%config);
    note( Dumper $result );
    ok(exists $result->{code}, 'Result has code field');
    ok(exists $result->{response}, 'Result has response field');

};

# DBOD::Api::remove_ip_alias
subtest 'remove_ip_alias' => sub {
    
    $rest_client->mock('responseCode', sub { return "204" } );
    $rest_client->mock('responseContent', sub { return "" } );
    ok(DBOD::Api::remove_ip_alias($entity, \%config), "Method call");
    my $result = DBOD::Api::remove_ip_alias($entity, \%config);
    note (Dumper $result);
    ok(exists $result->{code}, 'Result has code fieldd');
    ok(!exists $result->{response}, 'Result has not response field');
    
    # Test failure
    $rest_client->mock('responseCode', sub { return "404" } );
    $rest_client->mock('responseContent', sub { return "" } );
    ok(DBOD::Api::remove_ip_alias($entity, \%config), "Method call: error");
    $result = DBOD::Api::remove_ip_alias($entity, \%config);
    note (Dumper $result);
    ok(exists $result->{code}, 'Result has code fieldd');
    ok(!exists $result->{response}, 'Result has not response field');

};

# DBOD::Api::set_metadata 
subtest 'set_metadata' => sub {

    my $metadata = { host => "a", port => "1234" };

    $rest_client->mock('responseCode', sub { return "201" } );
    $rest_client->mock('responseContent', sub { return "{\"ipalias\":\"dbod-test\"}" } );
    ok(DBOD::Api::set_metadata($entity, $metadata, \%config), "Method call");
    my $result = DBOD::Api::set_metadata($entity, \%config);
    note (Dumper $result);
    ok(exists $result->{code}, 'Result has code fieldd');
    ok(!exists $result->{response}, 'Result has not response field');
    
    # Test failure
    $rest_client->mock('responseCode', sub { return "404" } );
    $rest_client->mock('responseContent', sub { return "" } );
    ok(DBOD::Api::set_metadata($entity, \%config), "set_metadata: error");
    $result = DBOD::Api::set_metadata($entity, \%config);
    note (Dumper $result);
    ok(exists $result->{code}, 'Result has code fieldd');
    ok(!exists $result->{response}, 'Result has not response field');

};

# DBOD::Api::create_entity 
subtest 'create_entity' => sub {

    my $input = { dbname => "test", subcategory => "MYSQL" };
    print Dumper $input;

    $rest_client->mock('responseCode', sub { return "201" } );
    $rest_client->mock('responseContent', sub { return "" } );
    ok(DBOD::Api::create_entity($input, \%config), "Method call");
    my $result = DBOD::Api::create_entity($input, \%config);
    note (Dumper $result);
    ok(exists $result->{code}, 'Result has code field');
    
    # Test failure
    $rest_client->mock('responseCode', sub { return "404" } );
    $rest_client->mock('responseContent', sub { return "" } );
    ok(DBOD::Api::create_entity($input, \%config), "set_metadata: error");
    $result = DBOD::Api::create_entity($input, \%config);
    note (Dumper $result);
    ok(exists $result->{code}, 'Result has code field');

};

done_testing();

