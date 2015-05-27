# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Runtime;

use strict;
use warnings;

use Moose;
with 'MooseX::Log::Log4perl';

use Try::Tiny;
use IPC::Run qw(run timeout);
use Net::OpenSSH;

sub run_cmd {
    my ($self, $cmd_str, $timeout) = @_;
    my @cmd = split ' ', $cmd_str ;
    try {
        my ($out, $err);
        if (defined $timeout) {
            $self->log->debug("Executing ${cmd_str} with timeout: ${timeout}");
            run \@cmd, ,'>', \$out, '2>', \$err, (my $t = timeout $timeout);
        }
        else {
            $self->log->debug("Executing ${cmd_str}");
            run \@cmd, ,'>', \$out, '2>', \$err;
        }
        # If the command executed succesfully we return its exit code
        $self->log->debug("${cmd_str} return code: " . $?);
        return scalar $?;
    } 
    catch {
        if ($_ =~ /^IPC::Run: .*timeout/) {
            # Timeout exception
            $self->log->error("Timeout exception: " . $_);
            return;
        }
        else {
            # Other type of exception ocurred
            $self->log->error("Exception found: " . $_);
            return;
        }
    }
}

sub ssh {
    my($self, $cmd, $user, $password, $host, $str) = @_;
    my $ssh;
    $self->log->debug("Opening SSH connection ${user}\@${host}");
    $ssh = Net::OpenSSH->new("$user\@$host",
        password => $password,
        master_stdout_discard => 0,
        master_stderr_discard => 1);
    if ($ssh->error) {
        $self->log->error("SSH connection error: " . $ssh->error);
        return;
    }    
    $self->log->debug("Executing SSH ${cmd} at ${host}");
    my($stdout, $stderr) = $ssh->capture2({timeout => 60 }, $cmd); 
    if ($ssh->error) {
        $self->log->error("SSH Error: " . $ssh->error);
        $self->log->error("SSH Stdout: " . $stdout);
        $self->log->error("SSH Stderr: " . $stderr);
        return;
    }
    return scalar $stdout;
}

sub scp_get {
    my ($self, $user, $password, $host, $path_from, $path_to) = @_;
    my $ssh;
    $self->log->debug("Opening SSH connection ${user}\@${host}");
    $ssh = Net::OpenSSH->new("$user\@$host", password => $password,
                master_stdout_discard => 0,
                master_stderr_discard => 1,
                master_opts => [-o => "StrictHostKeyChecking=no",
                                -o => "UserKnownHostsFile=/dev/null"]);
    if ($ssh->error) {
        $self->log->error("SSH connection error: " . $ssh->error);
        return;
    }
    $self->log->debug("Executing scp_get ${path_from}, ${path_to}");
    $ssh->scp_get({recursive => 1}, $path_from, $path_to);
    if ($ssh->error) {
        $self->log->error("SSH Error: " . $ssh->error);
        return; 
    }
    
    return scalar 1;
}
