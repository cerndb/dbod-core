package DBOD;

use strict;
use warnings;
use Test::More;

use Log::Log4perl qw(:easy);
use DBOD::Job;

use Data::Dumper;

# Initiates logger
BEGIN { Log::Log4perl->easy_init() };

my $job = DBOD::Job->new_with_options( entity => 'test' );
$job->log->info("preparing to run job");

ok($job->run() == 0, "Simple Job execution");

done_testing(1);
