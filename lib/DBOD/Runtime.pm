# Copyright (C) 2015, CERN
# # This software is distributed under the terms of the GNU General Public
# # Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# # In applying this license, CERN does not waive the privileges and immunities
# # granted to it by virtue of its status as Intergovernmental Organization
# # or submit itself to any jurisdiction.

package DBOD::Runtime;

use strict;
use warnings;

use Try::Tiny;
use IPC::Run qw(run timeout);
use Net::OpenSSH;

sub run_cmd {
    my ($cmd_str, $timeout) = @_;
    my @cmd = split ' ', $cmd_str ;
    try {
        my ($out, $err);
        if (defined $timeout) {
            run \@cmd, ,'>', \$out, '2>', \$err, (my $t = timeout $timeout);
        }
        else {
            run \@cmd, ,'>', \$out, '2>', \$err;
        }
    } 
    catch {
        if ($_ =~ /^IPC::Run: .*timeout/) {
            # Timeout exception
            print "Timeout exception: " . $_;
        }
        else {
            # Other type of exception ocurred
        }
    }
}


