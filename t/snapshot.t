#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use_ok('DBOD::Snapshot');

# Example of a valid snapshot name
my $snapshot =  'snapscript_03122015_174427_222_5617';
# Version (in this case, MySQL 5.6.17)
my $version = '5617';
# PITR datetime
my $pitr = '2016-02-13_09:23:34';
my $pitr_past = '2014-02-13_09:23:34';
my $pitr_close = '2015-12-03_17:44:30';
my $pitr_invalid = '2015-13-03_17:44:30';

subtest 'check_time' => sub {
        ok(DBOD::Snapshot::check_times($snapshot, $pitr), 'Valid date pair');
        ok(!DBOD::Snapshot::check_times($snapshot . '_cold', $pitr), 'Cold snapshot');
        ok(!DBOD::Snapshot::check_times($snapshot . '_cold', $pitr_close), 'Cold snapshot, PITR too close');
        ok(!DBOD::Snapshot::check_times($snapshot, $pitr_past), 'Invalid date pair');
        ok(!DBOD::Snapshot::check_times('Invalid Snapshot', $pitr_past), 'Invalid snapshot');
        ok(!DBOD::Snapshot::check_times('Invalid Snapshot', $pitr_invalid), 'PITR Invalid date');
        ok(!DBOD::Snapshot::check_times('Invalid Snapshot', 'Invalid PITR'), 'Both dates invalid');
};

done_testing();

