# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Runtime;

use strict;
use warnings;
use base qw(Exporter);
use Log::Log4perl qw(:easy);

use Try::Tiny;
use IPC::Run qw(run timeout);
use Net::OpenSSH;
use Data::Dumper;
use File::Temp;
use File::Copy;
use Time::Local;
use Time::localtime;
use autodie qw(:io);

use DBOD;

our (@EXPORT_OK);

#Exported methods
@EXPORT_OK = qw(
    run_cmd
    mywait
    result_code
    wait_until_file_exist
    run_str
    get_instance_version
    read_file
    write_file_arr
    get_temp_filename
    );

sub run_cmd {
    my %args = @_;
    # Using named parameters, but unpacking for clarity and usability
    my $cmd_str = $args{cmd};
    my $timeout = $args{timeout};
    my $devnull = '/dev/null';
    my $output_ref = ( defined ($args{output}) ? $args{output}: \$devnull );
    my @cmd = split ' ', $cmd_str ;
    my ($err, $return_code);
    try {
        if (defined $timeout) {
            DEBUG "Executing ${cmd_str} with timeout: ${timeout}";
            run \@cmd, ,'>', $output_ref, '2>', \$err, (my $t = timeout $timeout);
        }
        else {
            DEBUG "Executing ${cmd_str}";
            run \@cmd, ,'>', $output_ref, '2>', \$err;
        }
        # If the command executed succesfully we return its exit code
        DEBUG "${cmd_str} stdout: " . $$output_ref;
        DEBUG "${cmd_str} return code: " . $?;
        $return_code = $?;
    } 
    catch {
        if ($_ =~ m{^IPC::Run: .*timeout}x) {
            # Timeout exception
            ERROR "Timeout exception: " . $_;
            ERROR "CMD stderr: " . $err;
            return;
        }
        else {
            # Other type of exception ocurred
            ERROR "Exception found: " . $_;
            if (defined $err) {
                ERROR  "CMD stderr: " . $err ;
            }
            return;
        }
    };
    return scalar $return_code;
}

sub mywait {
    my ($method, @params) = @_;
    my $result;
    DEBUG  "Calling $method with @params until obtaining results";
    $result= $method->(@params);
    my $time = 1.0;
    while (! defined $result) {
        DEBUG  "Received: $result. Waiting $time seconds" ;
        sleep $time;
        $time = $time * 2;
        $result = $method->(@params);
    }
    DEBUG $result;
    return $result;
}

sub result_code{
    my $log = shift;
    my @lines = split(m{\n}x, $log);
    my $code = undef;
    foreach (@lines){
        if ( $_ =~ m{\[(\d)\]}x ){
            $code = $1;
            DEBUG 'Found return code: ' . $code;
        }
    }
    if (defined $code){
        return scalar int($code);
    }
    else{
        # If the command doesn't return any result code, we take it as bad
        return scalar 1;
    }
}

sub wait_until_file_exist {
    my ($timeout, $filename) = @_;
    my $poll_interval = 1; # seconds
    DEBUG 'Waiting for creation of ' . $filename;
    until ((-e $filename) || ($timeout <= 0))
    {
        $timeout -= $poll_interval;
        sleep $poll_interval;
    }
    return scalar ( -e $filename );
}

#@deprecated To be substutituted by run_cmd
# Using it as interface to maintain the inverted logic for error handling
# until the required changes are made in the action scripts
sub run_str {
    my ($cmd, $output_ref, $fake, $text) = @_;
    my $rc = run_cmd(cmd => $cmd, output => $output_ref);
    if ($rc != 0) {
        ERROR " $cmd failed with return code: <$rc>";
        return $ERROR;
    } else {
        return $OK;
    }
}

# We maintain the method to keep compatibility with current calls
sub get_instance_version {
    my $version = shift;
    $version =~ tr/\.//d;
    DEBUG 'Processed version' . $version;
    return $version;
}

sub read_file {
    my $file = shift;
    INFO "Reading file: <$file>";
    try {
        open my $F, '<', $file;
        my (@text) = <$F>;
        close($F);
        return @text;
    } catch {
        ERROR  "Error: $_" ;
        return;
    };
}

sub write_file_arr {
    my ($file, $text) = @_;
    INFO "Writing file: <$file> # of lines: " . scalar(@$text);
    try {
        open my $F, '>', $file;
        foreach (@$text) {
            print $F $_;
        }
        close($F);
        return;
    } catch {
        ERROR  "Error: $_" ;
        return;
    };
}

#it expects three arguments, otherwise returns undef
#it returns a full patch <dir>/<filename>
sub get_temp_filename {
    my ($template, $directory, $suffix) = @_;
    if (! defined $template || ! defined $directory || ! defined $suffix) {
        DEBUG "some variable missing, please check ";
        return;
    }
    DEBUG "template: <$template> directory: <$directory> suffix: <$suffix> ";
    my $fh = File::Temp->new(
        TEMPLATE => $template,
        DIR      => $directory,
        SUFFIX   => $suffix,
        UNLINK   => 1,
    );

    #it returns a full patch <dir>/<filename>
    return $fh->filename;
}

1;
