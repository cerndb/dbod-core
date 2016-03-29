# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Job;

use strict;
use warnings;

our $VERSION = 0.67;

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

use DBOD::Config;
use DBOD::Network::Api qw( load_cache get_entity_metadata );
use DBOD::DB;

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
has 'db' => (is => 'rw', isa => 'Object',
    documentation => 'DB connection object');


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

# Initializes the $job->db obect with the connection parameters of the
# job target instance

sub connect_db {
    my ($self,) = @_;
    if (defined $self->metadata->{'subcategory'}) {
        # Set up db connector
        my $db_type = lc $self->metadata->{'subcategory'};
        my $db_user = $self->config->{$db_type}->{'db_user'};
        my $db_password = $self->config->{$db_type}->{'db_password'};

        my $dsn;
        my $db_attrs;
        $self->log->info('Creating DB connection with instance');
        for ($db_type) {
            if (m{^mysql$}x) {
                $dsn = "DBI:mysql:mysql_socket=" . $self->metadata->{'socket'};
                $db_attrs = {
                    AutoCommit => 1, 
                    };
            }
            if (m{^pgsql$}x) {
                $dsn = "DBI:Pg:dbname=postgres;host=" . $self->metadata->{'socket'}.
                 ";port=" . $self->metadata->{'port'};
                $db_attrs = {
                    AutoCommit => 1, 
		        RaiseError => 1,
                    };
            }
        };

        $self->db(DBOD::DB->new(
                      db_dsn  => $dsn,
                      db_user => $db_user,
                      db_password => $db_password,
                      db_attrs => $db_attrs,));
    }
    else { 
        $self->log->info('Skipping DB connection with instance');
    }

    return;

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
