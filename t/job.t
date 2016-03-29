package DBOD;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Test::More;

use_ok('DBOD::Job');

use Data::Dumper;
use File::ShareDir;
use Test::MockModule;

# Initiates logger
BEGIN { Log::Log4perl->easy_init() };
    

# Check class parameters
subtest 'Class parameters' => sub {
    use DBOD::Job;
    my $job = DBOD::Job->new_with_options( entity => 'test', debug => '1' );

    can_ok( $job, qw(run) );
    can_ok( $job, qw(connect_db) );
    isa_ok( $job->config, 'HASH', "Config type" );
    isa_ok( $job->metadata, 'HASH', "Metadata type" );
    isa_ok( $job->md_cache, 'HASH', "md_cache type" );
    $job->connect_db();
    is( $job->db, undef, "job->db undefined" );
};


# Check execution, job is succesfull
subtest 'Job execution' => sub {
    my $job1 = DBOD::Job->new_with_options( entity => 'test' );
    $job1->run( sub { return 0 } );
    is( $job1->_result(), 0, "Succesfull Job execution code" );

    my $job2 = DBOD::Job->new_with_options( entity => 'test' );
    $job2->run( sub { return 1 } );
    is( $job2->_result(), 1, "Succesfull Error execution code" );
};

subtest 'DB connection' => sub {

    my $share_dir = File::ShareDir::dist_dir('DBOD');
    my $filename = "$share_dir/test.json";

    my %config = ();
    my %mysql = ();
    $mysql{'db_user'} = 'travis';
    $mysql{'db_password'} = '';
    my %pg = ();
    $pg{'db_user'} = 'postgres';
    $pg{'db_password'} = '';

    $config{'mysql'} = \%mysql;
    $config{'pgsql'} = \%pg;

    my %api = ();
    $api{'cachefile'} = "$share_dir/entities.json";
    $api{'host'} = "https://api-server:443";
    $api{'timeout'} = "3";
    $api{'user'} = "API-USER";
    $api{'password'} = "XXXXXXXXX";
    $api{'entity_metadata_endpoint'} = "api/v1/entity";
    $api{'entity_ipalias_endpoint'} = "api/v1/entity/alias";

    $config{api} = \%api;

    # Mock get_entity_metadata and Config::load()
    my $api_mock = Test::MockModule->new('DBOD::Network::Api');
    my $config_mock = Test::MockModule->new('DBOD::Config');
    $config_mock->mock( load => sub { return \%config; } );

    # Test Mocking
    note Dumper DBOD::Config::load();

    # Test DB object initialization: MySQL
    my $job_mysql = DBOD::Job->new_with_options( entity => 'mysql_db' );
    $job_mysql->connect_db();
    isnt( $job_mysql->db, undef, "job->db connects to MySQL" );
    note Dumper $job_mysql->db;
    
    # Test DB object initialization: PG
    my $job_pg = DBOD::Job->new_with_options( entity => 'pg_db' );
    $job_pg->connect_db();
    isnt( $job_pg->db, undef, "job->db connects to PG" );
    note Dumper $job_pg->db;

};

done_testing;
