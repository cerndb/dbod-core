# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Network::Ldap;
use strict;
use warnings;

our $VERSION = 0.67;

use Net::LDAP;
use Net::LDAP::Entry;
use Net::LDAP::LDIF;
use YAML::Syck;

use Log::Log4perl qw(:easy);
use Data::Dumper;

use base qw(Exporter);

use DBOD;
use DBOD::Templates;


sub load_ldif {
    # Loads contents from an LDIF file and returns a reference to an array
    # of LDAP entries

    my $filename = shift;
    my $ldif = Net::LDAP::LDIF->new( $filename, "r", onerror => 'undef' );
    my @contents;
    while( not $ldif->eof() ) {
       my $entry = $ldif->read_entry();
       if ( $ldif->error() ) {
           ERROR "Error msg: ", $ldif->error ( ), "\n";
           ERROR "Error lines:\n", $ldif->error_lines ( ), "\n";
           return;
       } else {
           print Dumper $entry;
           push @contents, $entry;
       }
    }
    $ldif->done();
    return \@contents;
}

sub get_connection {
    # Expects a references to a configuration hash
    my $config = shift;
    DEBUG 'Opening LDAP connection to ' . 
        join ":", $config->{'ldap'}->{'protocol'}, 
            $config->{'ldap'}->{'url'}, 
            $config->{'ldap'}->{'port'};
    my $conn = Net::LDAP->new($config->{'ldap'}->{'url'}, 
        port => $config->{'ldap'}->{'port'}, 
        scheme => $config->{'ldap'}->{'protocol'}) or ERROR "$@";
    DEBUG 'Binding connection to ' . $config->{'ldap'}->{'userdn'};
    my $msg = $conn->bind($config->{'ldap'}->{'userdn'}, 
        password => $config->{'ldap'}->{'password'});
    $msg->code && ERROR $msg->error;
    return $conn;
}

sub timestamp_entity {
    # Adds a timestamp with the last modification time to the
    # SC-COMMENT attribute
    my ($conn, $entity) = @_;
    my $entity_name = "dod_" . lc $entity->{dbname};
    my $base = "SC-ENTITY=$entity_name,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
	DEBUG "Adding Timestamp to $base";
    DBOD::Network::Ldap::modify_attributes($conn, $base,
        ['SC-COMMENT' => 'Entity Modified @(' . localtime(time) . ')']);
    return;
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

sub create_instance {
    
    my ($new_instance, $config) = @_;
    DEBUG 'Creating LDAP entity: ' . Dumper $new_instance;

    my $entry = DBOD::Templates::create_ldap_entry($new_instance, $config);

    my $conn = get_connection($config);
    my $result;

    if (defined $conn) {
        for my $subtree (@{$entry}) {
			DEBUG "Adding " . $subtree;
            my $response = $conn->add($subtree);
			if ($response->code) {
                DEBUG "subtree: " . Dumper $subtree;
				ERROR "response: " . Dumper $response;
				ERROR $response->error;
                $result = $ERROR;
			}
		
        }
        timestamp_entity($conn, $new_instance);
        $conn->unbind();
        $conn->disconnect();
    } else {
        ERROR "Couldn\'t connect to LDAP server. Aborting instance registration";
        return scalar $ERROR;
    }
    if (defined $result) {
        return scalar $result;
    } else {
        return scalar $OK;
    }

}

sub delete_instance {
    my ($instance, $config) = @_;
    $instance= 'dod_'.$instance;
    DEBUG 'Deleting LDAP entity: ' . $instance;
    my $conn = get_connection($config);
    my $entities= get_entity($conn, "SC-ENTITY=$instance,SC-CATEGORY=entities,OU=syscontrol,DC=cern,DC=ch");
    if(scalar @$entities == 0){
	INFO 'no entry in Ldap';
    }
    # taken from https://github.com/perl-ldap/perl-ldap/blob/master/contrib/recursive-ldap-delete.pl:
    # delete the entries found in a sorted way:
    # those with more "," (= more elements) in their DN, which are deeper in the DIT, first
    # trick for the sorting: tr/,// returns number of , (see perlfaq4 for details)
    foreach my $e (sort { $b->dn =~ tr/,// <=> $a->dn =~ tr/,// } @$entities) {
        $conn->delete($e);
    }
    return scalar $OK;
}


1;
