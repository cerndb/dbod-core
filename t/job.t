package DBOD;

use strict;
use warnings;
use Test::More;

use Log::Log4perl qw(:easy);
use DBOD::Job;

use Data::Dumper;

# Initiates logger
BEGIN { Log::Log4perl->easy_init() };

my $job = DBOD::Job->new_with_options();
$job->log->info("preparing to run job");
$job->run();

