# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Ldap;
use strict;
use warnings;

sub add_alias {
    # Registers ip alias for the entity
    # 1. Register the ip-alias to the next free dnsname using the DBOD Api
    # 2. Add the ip-alias to the dnsname
    # 3. Performs DNS change 
    return;
}

sub remove_alias {
    # De-Registers ip alias for the entity
    # 1. Removes the ip-alias from the dnsname record
    # 2. De-register the ip-alias to the next free dnsname using the DBOD Api
    # 3. Performs DNS change 
    return;
}

# TODO
sub migrate_alias {
    # Change host associated to an ip-alias
    return;
}

1;
