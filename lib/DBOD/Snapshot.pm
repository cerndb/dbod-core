# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Snapshot;
use strict;
use warnings FATAL => 'all';
use Log::Log4perl qw(:easy);

use Time::Local;

# TODO: Substitute the Regexp validations for actual Date types checks.

sub check_times {
    # Check snapshot format and PITR provided
    my ($snapshot, $pitr)=@_;
    my $numsecs_restore = validate($snapshot);
    my $numsecs_pitr = validate_PITR($pitr);
    if ($numsecs_pitr && $numsecs_restore){
        if ($numsecs_pitr < $numsecs_restore) {
            ERROR "Time to pitr <".$pitr."> makes no sense for a restore: <".$snapshot.">";
            return 0;

        }
        if ($snapshot =~ /_cold$/x) {
            if ($numsecs_pitr < ($numsecs_restore + 15)) {
                ERROR "Using a cold snapshot <".$snapshot.">, PITR should at least 15 seconds later than snapshot!.";
                }
            ERROR "Cold snapshot selected!.";
            return 0;
        }
    }
    return 1;
}

sub validate {
    my $snapshot = shift;
    if ( $snapshot =~ /snapscript_(\d\d)(\d\d)(\d\d\d\d)_(\d\d)(\d\d)(\d\d)_(\d+)/x ) {
        my ($year_snap, $month_snap, $day_snap, $hour_snap, $min_snap, $sec_snap, $version);
        $year_snap=$3;
        $month_snap=$2;
        $day_snap=$1;
        $hour_snap=$4;
        $min_snap=$5;
        $sec_snap=$6;
        $version=$7;
        DEBUG "snapshot year: <$year_snap> month: <$month_snap> day: <$day_snap> hour: <$hour_snap> min: <$min_snap> sec: <$sec_snap> version: <$version>";
        return timelocal($sec_snap,$min_snap,$hour_snap,$day_snap,($month_snap -1),$year_snap);
    } else {
        ERROR "Problem parsing <" . $snapshot . ">";
        return;
    }
}

sub validate_PITR {
    my $pitr = shift;
    if ($pitr =~ /(\d\d\d\d)-(\d\d)-(\d\d)_(\d+):(\d+):(\d+)/x) {
        my($year_pitr,$month_pitr,$day_pitr,$hour_pitr,$min_pitr,$sec_pitr);
        $year_pitr=$1;
        $month_pitr=$2;
        $day_pitr=$3;
        $hour_pitr=$4;
        $min_pitr=$5;
        $sec_pitr=$6;
        DEBUG "year: <$year_pitr> month: <$month_pitr> day: <$day_pitr> hour: <$hour_pitr> min: <$min_pitr> sec: <$sec_pitr>";
        if ($month_pitr > 12 ) {
            ERROR "PITR: not right time format <" . $pitr . ">";
            return;
        }
        return timelocal($sec_pitr, $min_pitr, $hour_pitr, $day_pitr, ($month_pitr -1), $year_pitr);
    } else {
        ERROR "Problem parsing <" . $pitr . ">";
        return;
    }
}

1;