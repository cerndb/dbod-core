# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Job;

use strict;
use warnings;

our $VERSION = 0.70;

use Moose;
with 'MooseX::Log::Log4perl',
     'MooseX::Getopt::Usage';

sub getopt_usage_config {
    return (
        format   => "Usage: %c [OPTIONS]",
        headings => 0,
    );
 }

use Data::Dumper;
use Socket;

use DBOD;
use DBOD::Config;
use DBOD::Network::Api qw( load_cache get_entity_metadata );
use DBOD::DB;
use DBOD::Runtime;

# Input
has 'entity' => ( is => 'ro', isa => 'Str', required => 1,
    documentation => 'Entity to act on');
has 'debug' => (is => 'ro', isa => 'Bool', default=> 0,
    documentation => 'Enables debug messages');

# Internal attributes 
has 'md_cache' => (is => 'rw', isa =>'HashRef',
    documentation => 'Local metadata cache');
has 'config' => (is => 'rw', isa => 'HashRef',
    documentation => 'General configuration (from core.conf file)');
has 'metadata' => (is => 'rw', isa => 'HashRef',
    documentation => 'Entity metadata (from API)');

# output
has '_output' => ( is => 'rw', isa => 'Str' );
has '_result' => ( is => 'rw', isa => 'Num' );


# Constructor
sub BUILD {
    
    my $self = shift;
    
    # Remove screen appender from logger if debug is not enabled
    unless( $self->debug ) {
        Log::Log4perl::eradicate_appender('screen');
    }

    # Sets ENTITY environment variable os it can be used when loggin
    # This is an easy hack around not being able to find the right 
    # reference to use on the anonymous function used on the logger
    # CSPEC
    
    $ENV{ENTITY} = $self->entity;

    # Load General Configuration from file
    $self->config(DBOD::Config::load());

    # Load cache file
    my %cache = load_cache($self->config);
    $self->md_cache(\%cache);

    # Load entity metadata
    $self->metadata(
        get_entity_metadata($self->entity, $self->md_cache, $self->config));
    
    return;
};

sub is_local {
    my ($self, $ip_alias) = @_;
    unless (defined $ip_alias) {
        $ip_alias = 'dbod-' . lc $self->entity . ".cern.ch";
        $ip_alias =~ s/\_/\-/g;
    }
    $self->log->debug( 'Fetching IP address for '. $ip_alias );
    my $nip = inet_aton($ip_alias);
    my $host_ip;
    if (defined $nip) {
        $host_ip = inet_ntoa( $nip);
        $self->log->debug( 'Host IP: '.$host_ip );
    } else {
        $self->log->error('Error fetching host IP');
        return $FALSE;
    };
    my $host_addresses;
    $self->log->debug( 'Fetching local addresses' );
    DBOD::Runtime::run_cmd( cmd => 'hostname -I', output => \$host_addresses );
    my @addresses = split / /, $host_addresses;
    $self->log->debug($host_addresses);
    my $res = grep {/$host_ip/x} @addresses;
    return scalar $res;
}

sub run {
    my ($self, $body, $params) = @_;
    my $result = $body->($params);
    $self->_result($result);
    return;
}

after 'run' => sub {
    my $self = shift;
    $self->log->info('[' . $self->_result()  . ']');
};

1;
