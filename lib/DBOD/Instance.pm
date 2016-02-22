# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Instance;
use strict;
use warnings FATAL => 'all';
use Log::Log4perl qw (:easy);
use Data::Dumper;

our $VERSION = 0.67;
use Moose;
with 'MooseX::Log::Log4perl';
with 'MooseX::Getopt';


use DBOD::Config;
use DBOD::Api qw( load_cache get_entity_metadata );
use DBOD::DB;

# Attributes
## Input
has 'entity' => ( is => 'ro', isa => 'Str', required => 1);
## Public
has 'metadata' => (is => 'rw', isa => 'HashRef');
has 'state' => ( is => 'rw', isa => 'Str' );
has 'db' => (is => 'rw', isa => 'Object');

has 'config' => (is => 'rw', isa => 'HashRef');

# Class methods
## Public;
requires 'ping';
requires 'start';
requires 'stop';
requires 'snapshot';
requires 'recover';
requires upgrade;

## Private
requires '_connect_db';

#Constructor
sub BUILD {

    my $self = shift;

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

# Initializes the $instance->db obect with the connection parameters of the
# job target instance. To be overridden in sub-classes

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
            if (/^mysql$/) {
                $dsn = "DBI:mysql:mysql_socket=" . $self->metadata->{'socket'};
                $db_attrs = {
                    AutoCommit => 1,
                };
            }
            if (/^pgsql$/) {
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

1;