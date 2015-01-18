package DBOD;

use strict;
use warnings;
use Test::More;

use Log::Log4perl qw(:easy);
use DBOD::Job;

use Data::Dumper;

BEGIN { Log::Log4perl->easy_init() };

my $job = DBOD::Job->new( input => "<job input>" );
$job->log->info("preparing to run job");
$job->run();

