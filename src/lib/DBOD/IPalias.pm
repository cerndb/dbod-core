# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::IPalias;
use strict;
use warnings;

use DBOD::Runtime;
use DBOD::Api;

sub add_alias {
    # Registers ip alias for the entity
    # 1. Register the ip-alias to the next free dnsname using the DBOD Api
    # 2. Add the ip-alias to the dnsname on LANDB
    # 3. Performs DNS change 
    #
    # Returns false if it fails, true if it succeeds

    my ($entity, $config) = @_;
    DBOD::Api::set_ip_alias($entity, $config);
    my $result = DBOD::Api::get_ip_alias($entity, $config);
    if (defined $result) {
        # Extract dnsname and alias from JSON result of Api call
        my ($dnsname, $ipalias) = @{$result->{'response'}};
        # Register ip alias to dns name on the CERN Network service
        DBOD::Network::add_ip_alias($dnsname, $ipalias);
        # Generates DNS entry
        my $cmd = $config->{'ipalias'}->{'change_command'};
        my $command = $cmd . " --dnsname=" . $dnsname . " --alias=" . $ipalias;
        my $return_code = DBOD::Runtime->run_cmd($command);
        if ($return_code) {
            # An error ocurred executing external command
            return scalar 0;
        }
        else { 
            return scalar 1;
        }
    }
    else { 
        # An error occurred getting a free dnsname. Either the DB is down
        # or there are no more dnsnames free
        return scalar 0;
    }
}

sub remove_alias {
    # De-Registers ip alias for the entity
    # 1. Removes the ip-alias from the dnsname record
    # 2. De-register the ip-alias to the next free dnsname using the DBOD Api
    # 3. Performs DNS change 
    #
    # Returns false if it fails, true if it succeeds
    
    
    return;
}

# TODO
sub migrate_alias {
    # Change host associated to an ip-alias
    return;
}

1;
