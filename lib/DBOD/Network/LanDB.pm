# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Network::LanDB;

use strict;
use warnings;
use base qw(Exporter);

use Log::Log4perl qw(:easy);
use SOAP::Lite;

use DBOD;
use DBOD::Runtime;

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
    DEBUG 'LANDB Api client connection for ' . $username;
    my $call = $client->getAuthToken($username, $password, 'CERN');
    my $auth = $call->result;
    if ($call->fault) {
        ERROR "FAILED: " . $call->faultstring;
		die "Aborting execution";
    }
    my $authHeader = SOAP::Header->name('Auth' => { "token" => $auth });
    return ($client, $authHeader);
}

sub add_ip_alias {
    my ($dnsname, $alias, $config) = @_;
    my ($conn, $auth) = _get_landb_connection($config);
    my @views = ('internal', 'external');
    foreach my $scope_view (@views) {
        my $call = $conn->dnsDelegatedAliasAdd($auth, $dnsname, $scope_view, $alias);
        if ($call->fault) {
            ERROR "FAILED: " . $call->faultstring;
            return scalar $ERROR;
        }
    }
    return scalar $OK;
}
sub remove_ip_alias {
    my ($dnsname, $alias, $config) = @_;
    my ($conn, $auth) = _get_landb_connection($config);
    my @views = ('internal', 'external');
    foreach my $scope_view (@views) {
        my $call = $conn->dnsDelegatedAliasRemove($auth, $dnsname, $scope_view, $alias);
        if ($call->fault) {
            ERROR "FAILED: " . $call->faultstring;
            return scalar $ERROR;
        }
    }
    return scalar $OK;
}

sub get_ip_alias {
    my ($search, $config) = @_;
    my ($conn, $auth) = _get_landb_connection($config);
    my $call = $conn->dnsDelegatedSearch($auth, $search);
    if ($call->fault) {
        ERROR "FAILED: " . $call->faultstring;
        return;
    }
    return $call->result;

}

sub create_alias {

    my ($input, $config) = @_;

    DEBUG "Registering ip aplias $input->{ip_alias} in API for entity: $input->{dbname}";
    my $call = DBOD::Network::Api::set_ip_alias($input->{dbname}, $input->{ip_alias}, $config);
    my $dnsname = $call->{response}->[0];
    my $cmd = $config->{'ipalias'}->{'change_command'};
    my $host = $input->{hosts}->[0];
    my $command = $cmd . " --dnsname=" . $dnsname . " --add_ip=" . $host;
    DEBUG 'Adding entry to DNS by executing: ' . $command;
    my $return_code = DBOD::Runtime::run_cmd(cmd => $command);
    if ($return_code) {
        # An error ocurred executing external command
        ERROR 'An error occurred creating DNS entry for ip-alias';
        return scalar $return_code;
    }
    DEBUG "Adding ipalias $input->{ip_alias} to dnsname: $dnsname";
    $return_code = add_ip_alias($dnsname, $input->{ip_alias}, $config);
    if ($return_code) {
        ERROR 'Error adding IP alias to dnsname';
    }
    return scalar $return_code;
}

1;

