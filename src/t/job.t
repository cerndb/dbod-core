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
{
    my $job = DBOD::Job->new_with_options( entity => 'test' );
    can_ok( $job, qw(run) );
    isa_ok( $job->config, 'HASH', "Config type" );
    isa_ok( $job->metadata, 'HASH', "Metadata type" );
    isa_ok( $job->md_cache, 'HASH', "md_cache type" );
    is( $job->db, undef, "job->db undefined" );
}

# Check execution, job is succesfull
{
    my $job = DBOD::Job->new_with_options( entity => 'test' );
    $job->run( sub { return 0 } );
    is( $job->_result(), 0, "Succesfull Job execution code" );
}

# Check execution, job has errored
{
    my $job = DBOD::Job->new_with_options( entity => 'test' );
    $job->run( sub { return 1 } );
    is( $job->_result(), 1, "Succesfull Error execution code" );
}

done_testing;
