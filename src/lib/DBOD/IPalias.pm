# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::IPalias;
use strict;
use warnings;

use Log::Log4perl qw(:easy);
use DBOD::Runtime;
use DBOD::Api;
use DBOD::Network;

sub add_alias {
    # Registers ip alias for the entity
    # 1. Register the ip-alias to the next free dnsname using the DBOD Api
    # 2. Add the ip-alias to the dnsname on LANDB
    # 3. Performs DNS change 
    #
    # Returns false if it fails, true if it succeeds

    my ($entity, $config) = @_;
    my $ipalias = "dbod-" . $entity;
    $ipalias =~ s/\_/\-/g; # Substitutes underscores for dashes for ip-alias
    DBOD::Api::set_ip_alias($entity, $ipalias, $config);
    my $result = DBOD::Api::get_ip_alias($entity, $config);
    my ($dnsname, $host);
    if (defined $result) {
        ($dnsname, $ipalias) = @{$result->{'response'}};
        # Extract dnsname and alias from JSON result of Api call
        # Register ip alias to dns name on the CERN Network service
        DBOD::Network::add_ip_alias($dnsname, $ipalias, $config);
        # Generates DNS entry
        my $cmd = $config->{'ipalias'}->{'change_command'};
        my $command = $cmd . " --dnsname=" . $dnsname . " --add_ip=" . $host;
        DEBUG 'Executing ' . $cmd;
        return ;
        #my $return_code = DBOD::Runtime->run_cmd($command);
        my $return_code = 0;
        if ($return_code) {
            # An error ocurred executing external command
            ERROR 'An error occurred creating DNS entry for ip-alias';
            return scalar 0;
        }
        else { 
            INFO "Registerd alias %s to dnsname %s, host %s",
                $ipalias, $dnsname, $host;
            return scalar 1;
        }
    }
    else { 
        # An error occurred getting a free dnsname. Either the DB is down
        # or there are no more dnsnames free
        ERROR sprintf "Error registering alias %s to dnsname %s, host %s",
            $ipalias, $dnsname, $host;
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
    
    my ($entity, $config) = @_;
    my $result = DBOD::Api::get_ip_alias($entity, $config);
    DBOD::Api::remove_ip_alias($entity, $config);
    my ($dnsname, $host, $ipalias);
    if (defined $result) {
        ($dnsname, $ipalias) = @{$result->{'response'}};
        # Extract dnsname and alias from JSON result of Api call
        # Register ip alias to dns name on the CERN Network service
        DBOD::Network::remove_ip_alias($dnsname, $ipalias, $config);
        # Generates DNS entry
        my $cmd = $config->{'ipalias'}->{'change_command'};
        my $command = $cmd . " --dnsname=" . $dnsname . " --add_ip=" . $host;
        DEBUG 'Executing ' . $cmd;
        return ;
        #my $return_code = DBOD::Runtime->run_cmd($command);
        my $return_code = 0;
        if ($return_code) {
            # An error ocurred executing external command
            ERROR 'An error occurred creating DNS entry for ip-alias';
            return scalar 0;
        }
        else { 
            INFO "Registerd alias %s to dnsname %s, host %s",
                $ipalias, $dnsname, $host;
            return scalar 1;
        }
    }
    else { 
        # An error occurred getting a free dnsname. Either the DB is down
        # or there are no more dnsnames free
        ERROR sprintf "Error registering alias %s to dnsname %s, host %s",
            $ipalias, $dnsname, $host;
        return scalar 0;
    }
}
    

# TODO
sub migrate_alias {
    # Change host associated to an ip-alias
    return;
}

1;
