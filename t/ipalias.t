use strict;
use warnings;
use DBOD::Config;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::Network::IPalias');

use Test::MockObject;
use Test::MockModule;
use Test::MockObject::Extends;

use DBOD;

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

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
my $api_m = Test::MockModule->new('DBOD::Network::Api');
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

my $network = Test::MockModule->new('DBOD::Network::LanDB');
$network->mock( _get_landb_connection => sub { return ($client, $auth);} );

my $share_dir = DBOD::Config::get_share_dir();
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

my $runtime = Test::MockModule->new('DBOD::Runtime');
    
my $input = { 
	dbname => "test", 
	subcategory => "MYSQL",
	hosts => ["hostname"],
};

subtest 'add_alias' => sub {
        
        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = "output OK";
                return $DBOD::OK;
            });

        is(DBOD::Network::IPalias::add_alias($input, \%config),
            $DBOD::OK, 'Registered alias');

        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = "output ERROR";
                return $DBOD::ERROR;
            });
        
		$api_m->mock( get_ip_alias => sub {return undef} );

        is(DBOD::Network::IPalias::add_alias($input, \%config),
            $DBOD::ERROR, 'External failure: change_command');

        $api_m->mock( get_ip_alias => sub {return undef} );
        is(DBOD::Network::IPalias::add_alias($input, \%config),
            $DBOD::ERROR, 'API Failure');

};

subtest 'remove_alias' => sub {

        $api_m->mock( get_ip_alias => sub {return \%result} );

        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = "output OK";
                return $DBOD::OK;
            });

        is(DBOD::Network::IPalias::remove_alias($input, \%config),
            $DBOD::OK, 'Removed alias');

        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = "output ERROR";
                return $DBOD::ERROR;
            });

        is(DBOD::Network::IPalias::remove_alias($input, \%config),
            $DBOD::ERROR, 'External failure: change_command');

        $api_m->mock( get_ip_alias => sub {return undef} );
        is(DBOD::Network::IPalias::remove_alias($input, \%config),
            $DBOD::ERROR, 'API Failure');

};

done_testing();
