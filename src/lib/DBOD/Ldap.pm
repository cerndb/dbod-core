# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Ldap;
use strict;
use warnings;

use Net::LDAP;
use Net::LDAP::Entry;
use Net::LDAP::LDIF;
use YAML::Syck;

use Log::Log4perl qw(:easy);
use Data::Dumper;

use base qw(Exporter);

sub get_connection {
    # Expects a references to a configuration hash
    my $config = shift;
    DEBUG 'Opening LDAP connection to ' . 
        join ":", $config->{'ldap'}->{'protocol'}, 
            $config->{'ldap'}->{'url'}, 
            $config->{'ldap'}->{'port'};
    my $conn = Net::LDAP->new($config->{'ldap'}->{'url'}, 
        port => $config->{'ldap'}->{'port'}, 
        scheme => $config->{'ldap'}->{'protocol'}) or croak("$@");
    DEBUG 'Binding connection to ' . $config->{'ldap'}->{'userdn'};
    my $msg = $conn->bind($config->{'ldap'}->{'userdn'}, 
        password => $config->{'ldap'}->{'password'});
    $msg->code && ERROR $msg->error;
    return $conn;
}

sub get_entity {
    # Fetches full tree of a DBOD Entity
    my ($conn, $entity_base, $scope) = @_;
    my $filter = "(objectClass=*)";
    $scope = 'subtree' unless defined $scope;
    DEBUG "Fetching LDAP entity at: " . $entity_base;
    my $mesg = $conn->search(
            base => $entity_base,
            scope => $scope,
            filter => $filter);
   
    my @entries = $mesg->entries;
    return \@entries;
}

sub add_attributes {
    # Sample @attributes:
    #
    #     ['SC-PACKAGES-GROUP' => 'DBOD_RHEL6',
    #      'SC-PACKAGES-GROUP' => 'DBOD_SLC6OS',]
    #
    my ($conn, $entity_base, @attributes) = @_;
    DEBUG "Adding attributes:  " . Dumper @attributes . " to :" . $entity_base;
    my $result = $conn->modify($entity_base, add => @attributes);
    $result->code && ERROR $result->error;
    return $result->code;
}

sub modify_attributes {
    # Sample @attributes:
    #
    #     ['SC-PACKAGES-GROUP' => 'DBOD_RHEL6',
    #      'SC-PACKAGES-GROUP' => 'DBOD_SLC6OS',]
    #
    my ($conn, $entity_base, @attributes) = @_;
    DEBUG "Modifying attributes:  " . Dumper @attributes . " at :" . $entity_base;
    my $result = $conn->modify($entity_base, replace => @attributes);
    $result->code && ERROR $result->error;
    return $result->code;
}

1;
