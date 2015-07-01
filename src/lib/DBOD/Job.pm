# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Job;

use strict;
use warnings;

use Moose;
with 'MooseX::Log::Log4perl';
with 'MooseX::Getopt';

use Data::Dumper;
use DBD::Oracle qw(:ora_session_modes :ora_types);

use DBOD::Config;
use DBOD::Api qw( load_cache get_entity_metadata );
use DBOD::DB;


# Input
has 'entity' => ( is => 'ro', isa => 'Str', required => 1);
has 'debug' => (is => 'ro', isa => 'Bool', default=> 0);

# Internal attributes
has 'md_cache' => (is => 'rw', isa =>'HashRef');
has 'config' => (is => 'rw', isa => 'HashRef');
has 'metadata' => (is => 'rw', isa => 'HashRef');
has 'db' => (is => 'rw', isa => 'Object');


# output
has '_output' => ( is => 'rw', isa => 'Str', );
has '_result' => ( is => 'rw', isa => 'Num', );


sub BUILD {
    my $self = shift;
    # Remove screen appender from logger if debug is not enabled
    unless( $self->debug ) {
        Log::Log4perl::eradicate_appender('screen');
    }
    # Load General Configuration from file
    $self->config(DBOD::Config::load());
    # Load cache file
    my %cache = load_cache($self->config);
    $self->md_cache(\%cache);
    # Load entity metadata
    $self->metadata(
        get_entity_metadata($self->entity, $self->md_cache, $self->config));
    # Set up db connector
    my $db_type = lc $self->metadata->{'subcategory'};
    my $db_user = $self->config->{$db_type}->{'db_user'};
    my $db_password = $self->config->{$db_type}->{'db_password'};

    my $dsn;
    my $db_attrs;
    for ($db_type) {
        if (/^mysql$/) {
            $dsn = "DBI:mysql:mysql_socket=" . $self->metadata->{'socket'};
            $db_attrs = {
                AutoCommit => 1, 
                };
        }
        if (/^pgsql$/) {
            $dsn = "DBI:Pg:host=" . $self->metadata->{'hosts'}[0] .
             ";port=" . $self->metadata->{'port'};
            $db_attrs = {
                AutoCommit => 1, 
                };
        }
        if (/^oracle$/) {
            my $sid = $self->metadata->{'sid'};
            $dsn = "DBI:oracle:$sid";
            $db_attrs = {
                AutoCommit => 1, 
                ora_session_mode => ORA_SYSDBA,
                ora_client_info => 'DBOD-core', 
                ora_verbose => 0 };
        }
    };

    $self->db(DBOD::DB->new(
                  db_dsn  => $dsn,
                  db_user => $db_user,
                  db_password => $db_password,
                  db_attrs => $db_attrs,));
    return;
};

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
