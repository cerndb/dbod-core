# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Network::IPalias;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use DBOD;
use DBOD::Runtime;
use DBOD::Network::Api;
use DBOD::Network::LanDB;
use Data::Dumper;

sub add_alias {
    # Registers ip alias for the dbname
    # 1. Register the ip-alias to the next free dnsname using the DBOD Api
    # 2. Add the ip-alias to the dnsname on LANDB
    # 3. Performs DNS change 

    my ($input, $config) = @_;
	my $dbname = $input->{dbname};
	my $host = $input->{hosts}->[0];
    my $ipalias = "dbod-" . $dbname;
    $ipalias =~ s/\_/\-/gx; # Substitutes underscores for dashes for ip-alias
    my $response = DBOD::Network::Api::get_ip_alias($dbname, $config);
    my $resp;
    DEBUG 'get_ip_alias API Response: ' . Dumper $response;
	if (defined $response) {
        my ($dnsname, $ipalias) = @{$response};
		INFO "IP Alias already exists, nothing to do";
		INFO " DNS name: " . $dnsname;
		INFO " IP Alias: " . $ipalias;
		return scalar $OK;
	} else {
		# Register a dns-name to the instance IP alias
	    $response = DBOD::Network::Api::set_ip_alias($dbname, $ipalias, $config);
        DEBUG 'set_ip_alias API response: ' . Dumper $response;
	}
    if ($response == $OK) {
        my $response = DBOD::Network::Api::get_ip_alias($dbname, $config);
        # Extract dnsname and alias from JSON response of Api call
        # Register ip alias to dns name on the CERN Network service
        DBOD::Network::LanDB::add_ip_alias($response->{dnsname}, $response->{alias}, $config);
        # Generates DNS entry
        my $cmd = $config->{'ipalias'}->{'change_command'};
        my $command = $cmd . " --dnsname=" . $response->{dnsname} . " --add_ip=" . $host;
        DEBUG 'Executing ' . $command;
        my $return_code = DBOD::Runtime::run_cmd(cmd => $command);
        if ($return_code == $ERROR) {
            # An error ocurred executing external command
            ERROR 'An error occurred creating DNS entry for ip-alias';
            return scalar $ERROR;
        }
        else { 
            INFO sprintf("Registerd alias: %s to dnsname: %s, host: %s",
                $response->{ipalias}, $response->{dnsname}, $host);
            return scalar $OK;
        }
    }
    else { 
        # An error occurred getting a free dnsname. Either the DB is down
        # or there are no more dnsnames free
        ERROR sprintf("Error registering alias %s to host: %s", $ipalias, $host);
        return scalar $ERROR;
    }
}

sub remove_alias {
    # De-Registers ip alias for the entity
    # 1. Removes the ip-alias from the dnsname record
    # 2. De-register the ip-alias to the next free dnsname using the DBOD Api
    # 3. Performs DNS change 
    #
    # Returns false if it fails, true if it succeeds
    
    my ($input, $config) = @_;
	my $dbname = $input->{dbname};
	my $host = $input->{hosts}->[0];
    my $response = DBOD::Network::Api::get_ip_alias($dbname, $config);
	DEBUG 'get_ip_alias API response: ' . Dumper $response;

    my $res = DBOD::Network::Api::remove_ip_alias($dbname, $config);
    if (( defined $res) && ( $res == $OK)) {
        my $resp = shift @{$response->{'response'}};
        # Register ip alias to dns name on the CERN Network service
        DBOD::Network::LanDB::remove_ip_alias($resp->{dnsname}, $resp->{alias}, $config);
        # Generates DNS entry
        my $cmd = $config->{'ipalias'}->{'change_command'};
        my $command = $cmd . " --dnsname=" . $resp->{dnsname} . " --rm_ip=" . $host;
        DEBUG 'Executing ' . $command;
        my $return_code = DBOD::Runtime::run_cmd(cmd => $command);
        if ($return_code == $ERROR) {
            # An error ocurred executing external command
            ERROR 'An error occurred creating DNS entry for ip-alias';
            return scalar $ERROR;
        }
        else { 
            INFO sprintf("Registerd alias: %s to dnsname: %s, host: %s",
                $resp->{alias}, $resp->{dnsname}, $host);
            return scalar $OK;
        }
    }
    else { 
        # An error occurred removing the alias
        ERROR "Error removing alias from host: %s", $host;
        return scalar $ERROR;
    }
}
    
1;
