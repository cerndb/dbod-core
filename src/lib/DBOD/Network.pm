# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Network;

use strict;
use warnings;
use Exporter;

use Log::Log4perl qw(:easy);
use SOAP::Lite;

use base qw(Exporter);

sub _get_landb_connection {

    my $config = shift;
    # Get connector
    my $client=SOAP::Lite
        ->uri('http://network.cern.ch/NetworkService')
        ->xmlschema('http://www.w3.org/2001/XMLSchema')
        ->proxy('https://network.cern.ch/sc/soap/soap.fcgi?v=5', keep_alive=>1);

    #Get Auth token
    my $username = $config->{'network'}->{'username'};
    my $password = $config->{'network'}->{'password'};
    my $call = $client->getAuthToken($username, $password, 'NICE');
    my $auth = $call->result;
    if ($call->fault) {
        ERROR "FAILED: " . $call->faultstring;
    }
    my $authHeader = SOAP::Header->name('Auth' => { "token" => $auth });
    return ($client, $authHeader);
}

sub _landb_add_alias {
    my ($host, $alias) = @_;
    my ($conn, $auth) = _get_landb_connection();
    my $call = $conn->interfaceAddAlias($auth, uc($host), $alias);
    if ($call->fault) {
        ERROR "FAILED: " . $call->faultstring;
    }
}

sub set_ip_alias {
    my ($dnsname, $alias) = @_;
    my ($conn, $auth) = _get_landb_connection();
    my @views = ('internal', 'external');
    foreach my $scope_view (@views) {
        my $call = $conn->dnsDelegatedAliasAdd($auth, $dnsname, $scope_view, $alias);
        if ($call->fault) {
            ERROR "FAILED: " . $call->faultstring;
        }
    }
}
sub remove_ip_alias {
    my ($dnsname, $alias) = @_;
    my ($conn, $auth) = _get_landb_connection();
    my @views = ('internal', 'external');
    foreach my $scope_view (@views) {
        my $call = $conn->dnsDelegatedAliasRemove($auth, $dnsname, $scope_view, $alias);
        if ($call->fault) {
            ERROR "FAILED: " . $call->faultstring;
        }
    }
}

sub get_ip_alias {
    my ($search) = @_;
    my ($conn, $auth) = _get_landb_connection();
    my $call = $conn->dnsDelegatedAliasAdd($auth, $search);
    if ($call->fault) {
        ERROR "FAILED: " . $call->faultstring;
    }
}

1

