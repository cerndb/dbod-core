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

# DBOD::Api::load_cache
note( "%config is " . Dumper \%config );
my %cache = DBOD::Api::load_cache(\%config);
note( Dumper \%cache );

isa_ok(\%cache, 'HASH');
ok(exists $cache{'a'});
ok(exists $cache{'c'});
is($cache{'b'}{'prop1'}, 'value1');

# Mocking API client
my $api = Test::MockModule->new('DBOD::Api');

my $rest_client = Test::MockObject->new();
$rest_client->set_true('addHeader');
$rest_client->set_true('getUseragent');
$rest_client->set_true('buildQuery');
$rest_client->mock('GET');
$rest_client->mock('PUT');
$rest_client->mock('POST');
$rest_client->mock('DELETE');

# DBOD::Api::api_client needs to be mocked
$api->mock( _api_client => $rest_client );

my $entity = 'success';

# DBOD::Api::get_entity_metadata
$rest_client->mock('responseCode', sub { return "200" } );
$rest_client->mock('responseContent', sub { return "{\"metadata\":\"test\"}" } );
ok(DBOD::Api::get_entity_metadata('unexistant', \%cache, \%config), "get_entity_metadata");
my $metadata = DBOD::Api::get_entity_metadata('unexistant', \%cache, \%config);
ok(exists $metadata->{metadata}, "metadata has metadata field");
note( Dumper $metadata );
isa_ok($metadata, 'HASH', 'metadata');
$rest_client->mock('responseCode', sub { return "404" } );
$rest_client->mock('responseContent', sub { return "" } );
ok(DBOD::Api::get_entity_metadata('unexistant', \%cache, \%config), "get_entity_metadata: error");
$metadata = DBOD::Api::get_entity_metadata('unexistant', \%cache, \%config);
ok(!exists $metadata->{metadata}, "metadata is empty");


# DBOD::Api::get_ip_alias
$rest_client->mock('responseCode', sub { return "200" } );
$rest_client->mock('responseContent', sub { return "{\"ipalias\":\"dbod-test\"}" } );
ok(DBOD::Api::get_ip_alias($entity, \%config), "get_ip_alias");
my $result = DBOD::Api::get_ip_alias($entity, \%config);
note( Dumper $result );
ok(exists $result->{code});
ok(exists $result->{response});
$rest_client->mock('responseCode', sub { return "404" } );
$rest_client->mock('responseContent', sub { return "" } );
ok(DBOD::Api::get_ip_alias($entity, \%config), "get_ip_alias: error");
$result = DBOD::Api::get_ip_alias($entity, \%config);
note( Dumper $result );
ok(exists $result->{code});
ok(exists $result->{response});

# DBOD::Api::set_ip_alias 
$rest_client->mock('responseCode', sub { return "201" } );
$rest_client->mock('responseContent', sub { return "{\"ipalias\":\"dbod-test\"}" } );
ok(DBOD::Api::set_ip_alias($entity, 'ip-alias',\%config), "set_ip_alias");
$result = DBOD::Api::set_ip_alias($entity, 'ip-alias',\%config);
note( Dumper $result );
ok(exists $result->{code});
ok(exists $result->{response});
$rest_client->mock('responseCode', sub { return "404" } );
$rest_client->mock('responseContent', sub { return "" } );
ok(DBOD::Api::set_ip_alias($entity, 'ip-alias',\%config), "set_ip_alias: error");
$result = DBOD::Api::set_ip_alias($entity, 'ip-alias',\%config);
note( Dumper $result );
ok(exists $result->{code});
ok(exists $result->{response});

# DBOD::Api::remove_ip_alias
$rest_client->mock('responseCode', sub { return "204" } );
$rest_client->mock('responseContent', sub { return "" } );
ok(DBOD::Api::remove_ip_alias($entity, \%config), "remove_ip_alias");
$result = DBOD::Api::remove_ip_alias($entity, \%config);
note (Dumper $result);
ok(exists $result->{code});
ok(!exists $result->{response});
$rest_client->mock('responseCode', sub { return "404" } );
$rest_client->mock('responseContent', sub { return "" } );
ok(DBOD::Api::remove_ip_alias($entity, \%config), "remove_ip_alias: error");
$result = DBOD::Api::remove_ip_alias($entity, \%config);
note (Dumper $result);
ok(exists $result->{code});
ok(!exists $result->{response});

# DBOD::Api::set_metadata 
$rest_client->mock('responseCode', sub { return "201" } );
$rest_client->mock('responseContent', sub { return "{\"ipalias\":\"dbod-test\"}" } );
ok(DBOD::Api::set_metadata($entity, $metadata, \%config), "set_metadata");
$result = DBOD::Api::set_metadata($entity, \%config);
note (Dumper $result);
ok(exists $result->{code});
ok(!exists $result->{response});
$rest_client->mock('responseCode', sub { return "404" } );
$rest_client->mock('responseContent', sub { return "" } );
ok(DBOD::Api::set_metadata($entity, \%config), "set_metadata: error");
$result = DBOD::Api::set_metadata($entity, \%config);
note (Dumper $result);
ok(exists $result->{code});
ok(!exists $result->{response});

# DBOD::Api::sub create_entity 
#$rest_client->mock('responseCode', sub { return "200" } );
#$rest_client->mock('responseContent', sub { return "{\"ipalias\":\"dbod-test\"}" } );
# ok(DBOD::Api::create_entity(\%config, \%config), "create_entity");

done_testing();

