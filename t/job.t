package DBOD;

use strict;
use warnings;
use Test::More;

use_ok('DBOD::Job');

use DBOD::Job;
use Data::Dumper;

# Initiates logger
BEGIN { Log::Log4perl->easy_init() };

my $job = DBOD::Job->new_with_options( entity => 'test' );
$job->log->info("preparing to run job");

sub body {
    $job->_result(0);
}

ok($job->run(\&body) == 0, "Simple Job execution");

done_testing(2);
