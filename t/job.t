package DBOD;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Test::More;
use Data::Dumper;
use_ok('DBOD::Job');

use File::ShareDir;
use Test::MockModule;
use Config;

use DBOD;

# Initiates logger
BEGIN {
    Log::Log4perl->easy_init();
};

my $runtime = Test::MockModule->new('DBOD::Runtime');

# Check class parameters
subtest 'Class parameters' => sub {

    use DBOD::Job;
    my $job = DBOD::Job->new_with_options( entity => 'test', debug => '1' );

    can_ok( $job, qw(run) );
    can_ok( $job, qw(is_local) );
    isa_ok( $job->config, 'HASH', "Config type" );
    isa_ok( $job->metadata, 'HASH', "Metadata type" );
    isa_ok( $job->md_cache, 'HASH', "md_cache type" );
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

subtest 'is_local' => sub {
        plan 'skip_all' if ($Config{osname} == 'darwin'); #skip tests if running in osx
        my $job = DBOD::Job->new_with_options(
            entity => 'test',
            debug => 1,
        );

        my $fqdn = `hostname -f`;
        chomp $fqdn;

        my $host_addresses = `hostname -I`;

        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = $host_addresses;
                return $OK;
            });

        is($job->is_local($fqdn), $TRUE, 'Local Job');
        is($job->is_local(), $FALSE, 'Remote Job');
    };

done_testing();
