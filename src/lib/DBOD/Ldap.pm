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

use base qw(Exporter);

sub get_LDAP_conn {
    # Expects a references to a configuration hash
    my $conf_ref = shift;
    my %config = %{$conf_ref};
    my $conn = Net::LDAP->new($config->{'ldap'}->{'url'}, 
        port => $config->{'ldap'}->{'port'}, 
        scheme => $config->{'ldap'}->{'protocol'}) or croak("$@");
    $msg = $conn->bind($config->{'ldap'}->{'userdn'}, 
        password => $config->{'ldap'}->{'password'});
    $msg->code && croak $msg->error;
    return $conn;
}

sub get_entity {
    # Fetches full tree of a DBOD Entity
    my ($conn, $entity_base, $scope) = @_;
    my $filter = "(objectClass=*)";
    $scope = 'subtree' unless defined $scope;
    my $mesg = $conn->search(
            base => $entity_base,
            scope => $scope,
            filter => $filter);
   
    my @entries = $mesg->entries;
    return \@entries;
}

sub load_LDIF {
    # Loads LDIF template, return LDAP::Entry
    my ($template, $conf_ref) = @_;
    my %config = %{$conf_ref};
    my $template_dir = $config->{'ldap'}->{'template_folder'};
    $ldif = Net::LDAP::LDIF->new( $template_dir . "${template}.ldif", "r", onerror => 'undef' );
    my @entries;
    while ( not $ldif->eof ( ) ) {
      $entry = $ldif->read_entry ( );
      if ( $ldif->error ( ) ) {
        print "Error msg: ", $ldif->error ( ), "\n";
        print "Error lines:\n", $ldif->error_lines ( ), "\n";
      }
      else {
          push @entries, $entry;
      }
    }
    $ldif->done ( );
    return \@entries;
}

sub add_attributes {
    # Sample @attributes:
    #
    #     ['SC-PACKAGES-GROUP' => 'DBOD_RHEL6',
    #      'SC-PACKAGES-GROUP' => 'DBOD_SLC6OS',]
    #
    my ($conn, $entity_base, @attributes) = @_;
    my $result = $conn->modify($entity_base, add => @attributes);
    $result->code && croak $result->error;
    return $result->code;
}

sub modify_attributes {
    # Sample @attributes:
    #
    #     ['SC-PACKAGES-GROUP' => 'DBOD_RHEL6',
    #      'SC-PACKAGES-GROUP' => 'DBOD_SLC6OS',]
    #
    my ($conn, $entity_base, @attributes) = @_;
    my $result = $conn->modify($entity_base, replace => @attributes);
    $result->code && croak $result->error;
    return $result->code;
}

1;
