package DBOD;

use strict;
use warnings;
use Test::More;

use_ok('DBOD::Job');

use DBOD::Job;
use Data::Dumper;

# Initiates logger
BEGIN { Log::Log4perl->easy_init() };

# Check class parameters
subtest 'Class parameters' => sub {
    my $job = DBOD::Job->new_with_options( entity => 'test', debug => '1' );
    can_ok( $job, qw(run) );
    isa_ok( $job->config, 'HASH', "Config type" );
    isa_ok( $job->metadata, 'HASH', "Metadata type" );
    isa_ok( $job->md_cache, 'HASH', "md_cache type" );
    is( $job->db, undef, "job->db undefined" );

    # Mock get_entity_metadata and Config::load()
    my %config = ();
    my %mysql = ();
    $mysql{'db_user'} = 'travis';
    $mysql{'db_password'} = '';
    my %pg = ();
    $mysql{'db_user'} = 'postgres';
    $mysql{'db_password'} = '';
    
    $config{'mysql'} = \%mysql;
    $config{'pg'} = \%pg;

    my %metadata = ();


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

done_testing;
