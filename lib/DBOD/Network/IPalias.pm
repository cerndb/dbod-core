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
		INFO "IP Alias already exists, nothing to do";
		INFO " DNS name: " . $response->{dns_name};
		INFO " IP Alias: " . $response->{alias};
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
        DBOD::Network::LanDB::add_ip_alias($response->{dns_name}, $response->{alias}, $config);
        # Generates DNS entry
        my $cmd = $config->{'ipalias'}->{'change_command'};
        my $command = $cmd . " --dnsname=" . $response->{dns_name} . " --add_ip=" . $host;
        DEBUG 'Executing ' . $command;
        my $return_code = DBOD::Runtime::run_cmd(cmd => $command);
        if ($return_code == $ERROR) {
            # An error ocurred executing external command
            ERROR 'An error occurred creating DNS entry for ip-alias';
            return scalar $ERROR;
        }
        else { 
            INFO sprintf("Registered alias: %s to dnsname: %s, host: %s",
                $response->{alias}, $response->{dns_name}, $host);
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
    
    my ($metadata, $config) = @_;
    my $dbname = $metadata->{db_name};
    my $hosts = join(',',@{$metadata->{hosts}});
    my $response = DBOD::Network::Api::get_ip_alias($dbname, $config);
    unless (defined $response){
        INFO "No ip alias found for $dbname, no need to remove it";
        return scalar $OK;
    }
    my $res = DBOD::Network::Api::remove_ip_alias($dbname, $config);
    if (( defined $res) && ( $res == $OK)) {
        # Register ip alias to dns name on the CERN Network service
        DBOD::Network::LanDB::remove_ip_alias($response->{dns_name}, $response->{alias}, $config);
        # Generates DNS entry
        my $cmd = $config->{'ipalias'}->{'change_command'};
        my $command = $cmd . " --dnsname=" . $response->{dns_name} . " --rm_ip=" . $hosts;
        DEBUG 'Executing ' . $command;
        my $return_code = DBOD::Runtime::run_cmd(cmd => $command);
        if ($return_code == $ERROR) {
            # An error ocurred executing external command
            ERROR 'An error occurred creating DNS entry for ip-alias';
            return scalar $ERROR;
        }
        else { 
            INFO sprintf("Removed alias: %s to dnsname: %s, hosts: %s",
                $response->{alias}, $response->{dns_name}, $hosts);
            return scalar $OK;
        }
    }
    else { 
        # An error occurred removing the alias
        ERROR "Error removing alias from hosts: %s", $hosts;
        return scalar $ERROR;
    }
}
    
1;
