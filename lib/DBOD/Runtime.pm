# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

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
        # If the command executed succesfully we return its exit code
        return $?;
    } 
    catch {
        if ($_ =~ /^IPC::Run: .*timeout/) {
            # Timeout exception
            print "Timeout exception: " . $_;
            return 0;
        }
        else {
            # Other type of exception ocurred
            return 0;
        }
    }
}

sub ssh {
    my($cmd, $user, $password, $host, $str) = @_;
    my $ssh;
    eval {  
        $ssh = Net::OpenSSH->new("$user\@$host",
            password => $password,
            master_stdout_discard => 0,
            master_stderr_discard => 1) or die $ssh->error;
    };
    if ($ssh->error) {
        return 0; #error
    } elsif ($@) {
        return 0; #error
    }
    my($output, $errput) = $ssh->capture2({timeout => 60 }, "$cmd"); 
    if ($ssh->error) {
        return 0; #error
    }
    if (defined $output && length($output) > 0) {
        push @$str, $output;
    }
    return 1; #ok
}

sub scp_get {
    my ($user, $password, $host, $path_from, $path_to) = @_;
    my $ssh;
    $ssh = Net::OpenSSH->new("$user\@$host", password => $password,
                master_stdout_discard => 0,
                master_stderr_discard => 1,
                master_opts => [-o => "StrictHostKeyChecking=no",
                                -o => "UserKnownHostsFile=/dev/null"]);
    if ($ssh->error){
        return 0;#error
    }
    $ssh->scp_get({recursive => 1}, $path_from, $path_to);
    if ($ssh->error){
        return 0;#error
    }
    else{
        return 1;# Succeded
    }
}
