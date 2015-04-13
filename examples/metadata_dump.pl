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
    my ($self, $entity, $params) = @_;
    $job->log->debug("Entity: " . $job->entity);
    $job->log->debug("General configuration ");
    $job->log->debug(Dumper $job->config);
    $job->log->debug("Entity metadata ");
    $job->log->debug(Dumper $job->metadata);
    return 0;
}

$job->run(\&body);

