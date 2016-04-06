# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Templates;

use warnings;
use strict;

our $VERSION = 0.67;

use DBOD::Network::Ldap;
use Data::Dumper;
use Template;
use Try::Tiny;
use File::Temp qw/ tempfile /;
use Log::Log4perl qw(:easy);
use Net::LDAP::LDIF;
use JSON;

sub load_template {
    my ($format, $db_type, $vars, $config, $output) = @_;
    try {
        DEBUG sprintf("Template folder: %s",  $config->{'common'}->{'template_folder'});
         my $tt = Template->new({
            INCLUDE_PATH => $config->{'common'}->{'template_folder'},
            INTERPOLATE  => 1,
         });
        DEBUG sprintf("Loading %s/%s", $format, $db_type);
        my $result = $tt->process(join('/',$format, $db_type), $vars, $output);
        unless ($result) {
            ERROR sprintf("Error populating template: %s/%s:", $format, $db_type);
            ERROR $tt->error();
        }
        return scalar 0;
    } catch {
        ERROR "Template error: $Template::ERROR\n";
        return scalar 1;
    };
    return scalar 0;
}


sub create_metadata {
    # Creates a new metadata object.
    my ($new_entity, $config) = @_;
    DEBUG 'Creating Metadata object for entity: ' . Dumper $new_entity;
    my $type = lc $new_entity->{subcategory};
    my $metadata;
    load_template 'json', $type, $new_entity, $config, \$metadata;
    DEBUG 'Metadata: ' . Dumper $metadata;
    return $metadata;
}

sub create_ldap_entry {
    # Creates a new metadata object.
    my ($new_entity, $config) = @_;
    DEBUG 'Creating Metadata object for entity: ' . Dumper $new_entity;
    my $type = lc $new_entity->{subcategory};
    my $ldap_template;
    load_template 'ldap', $type, $new_entity, $config, \$ldap_template;
    my ($fh, $filename) = tempfile();
    print $fh $ldap_template;
    close $fh;
    my $entries = DBOD::Network::Ldap::load_ldif($filename);
    DEBUG 'LDAP entry: ' . Dumper $entries;
    return $entries;
}

sub create_ldap_tnsnetservice_entry {
    my ($new_entity, $config) = @_;
    my $tnsnetservice;
    load_template 'ldap', 'tnsnetservice', $new_entity, $config, \$tnsnetservice;
    DEBUG 'Metadata: ' . Dumper $tnsnetservice;
    my ($fh, $filename) = tempfile();
    print $fh $tnsnetservice;
    close $fh;
    my $entries = DBOD::Network::Ldap::load_ldif($filename);
    DEBUG 'LDAP entry: ' . Dumper $entries;
    return $entries;
}

1;
