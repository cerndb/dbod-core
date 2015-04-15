package DBOD;

use strict;
use warnings;

use DBOD::Job;
use Data::Dumper;

# Initiates logger
BEGIN { 
    Log::Log4perl->easy_init() ;
}
my $job = DBOD::Job->new_with_options();

sub body {
    my $params = shift;
    print Dumper $job;
    return 0;
}

$job->run(\&body);

