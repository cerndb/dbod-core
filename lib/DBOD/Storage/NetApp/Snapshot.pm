# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Storage::NetApp::Snapshot;
use strict;
use warnings FATAL => 'all';
use Log::Log4perl qw(:easy);

use Time::Local;

# TODO: Substitute the Regexp validations for actual Date types checks.
# TODO: Add version validation
sub is_valid {
    # Check snapshot file format and PITR provided
    # Expected to return the snapshot version
    my ($snapshot, $pitr, $current_version) = @_;
    my ($numsecs, $version) = validate_snapshot($snapshot);
    my $numsecs_pitr = validate_PITR($pitr) if defined($pitr);
    if ($version != $current_version){
        ERROR "Snapshot version missmatch";
        return 0;
    }
    elsif ($numsecs_pitr && $numsecs){
        if ($numsecs_pitr < $numsecs) {
            ERROR "Time to pitr <".$pitr."> makes no sense for a restore: <".$snapshot.">";
            return 0;
        }
        if (($snapshot =~ /_cold$/x) && ($numsecs_pitr < ($numsecs + 15))) {
            ERROR "Using a cold snapshot <" . $snapshot .
                    "> PITR should at least 15 seconds later than snapshot!.";
            return 0;
        }
    }
    return 1;
}

sub validate_snapshot {
    my $snapshot = shift;
    if ( $snapshot =~ /snapscript_(\d\d)(\d\d)(\d\d\d\d)_(\d\d)(\d\d)(\d\d)_(\d+)_(\d+)/x ) {
        my ($year, $month, $day, $hour, $min, $sec, $binlog, $version);
        $year=$3;
        $month=$2;
        $day=$1;
        $hour=$4;
        $min=$5;
        $sec=$6;
        $binlog=$7;
        $version=$8;
        DEBUG "Snapshot taken at $year-$month-$day $hour:$min:$sec Binlog: $binlog, Version: <$version>";
        return (timelocal($sec,$min,$hour,$day,($month -1),$year), $version);
    } else {
        ERROR "Problem parsing <" . $snapshot . ">";
        return;
    }
}

sub validate_PITR {
    my $pitr = shift;
    if ($pitr =~ /(\d\d\d\d)-(\d\d)-(\d\d)_(\d+):(\d+):(\d+)/x) {
        my ($year, $month, $day, $hour, $min, $sec);
        $year=$1;
        $month=$2;
        $day=$3;
        $hour=$4;
        $min=$5;
        $sec=$6;
        DEBUG "PITR to $year-$month-$day $hour:$min:$sec";
        return timelocal($sec, $min, $hour, $day, ($month -1), $year);
    } else {
        ERROR "Problem parsing <" . $pitr . ">";
        return;
    }
}

1;
