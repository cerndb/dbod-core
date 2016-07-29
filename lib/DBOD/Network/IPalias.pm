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
    my $result = DBOD::Network::Api::get_ip_alias($dbname, $config);
	if (defined $result->{response}) {
		INFO "IP Alias already exists, nothing to do";
		INFO " DNS name: " . $result->{response}->[0];
		INFO " IP Alias: " . $result->{response}->[1];
		return scalar $OK;
	} else {
		# Register a dns-name to the instance IP alias
	    DBOD::Network::Api::set_ip_alias($dbname, $ipalias, $config);
		$result = DBOD::Network::Api::get_ip_alias($dbname, $config);
	}
    my $dnsname;
    if (defined $result) {
        ($dnsname, $ipalias) = @{$result->{'response'}};
        # Extract dnsname and alias from JSON result of Api call
        # Register ip alias to dns name on the CERN Network service
        DBOD::Network::LanDB::add_ip_alias($dnsname, $ipalias, $config);
        # Generates DNS entry
        my $cmd = $config->{'ipalias'}->{'change_command'};
        my $command = $cmd . " --dnsname=" . $dnsname . " --add_ip=" . $host;
        DEBUG 'Executing ' . $command;
        my $return_code = DBOD::Runtime::run_cmd(cmd => $command);
        if ($return_code == $ERROR) {
            # An error ocurred executing external command
            ERROR 'An error occurred creating DNS entry for ip-alias';
            return scalar $ERROR;
        }
        else { 
            INFO sprintf("Registerd alias: %s to dnsname: %s, host: %s",
                $ipalias, $dnsname, $host);
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
    my $result = DBOD::Network::Api::get_ip_alias($dbname, $config);
    DBOD::Network::Api::remove_ip_alias($dbname, $config);
    if (defined $result) {
        my ($dnsname, $ipalias) = @{$result->{'response'}};
        # Extract dnsname and alias from JSON result of Api call
        # Register ip alias to dns name on the CERN Network service
        DBOD::Network::LanDB::remove_ip_alias($dnsname, $ipalias, $config);
        # Generates DNS entry
        my $cmd = $config->{'ipalias'}->{'change_command'};
        my $command = $cmd . " --dnsname=" . $dnsname . " --rm_ip=" . $host;
        DEBUG 'Executing ' . $command;
        my $return_code = DBOD::Runtime::run_cmd(cmd => $command);
        if ($return_code == $ERROR) {
            # An error ocurred executing external command
            ERROR 'An error occurred creating DNS entry for ip-alias';
            return scalar $ERROR;
        }
        else { 
            INFO sprintf("Registerd alias: %s to dnsname: %s, host: %s",
                $ipalias, $dnsname, $host);
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
