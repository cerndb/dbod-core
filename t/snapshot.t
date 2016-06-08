#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use_ok('DBOD::Storage::NetApp::Snapshot');

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

# Example of a valid snapshot name
my $snapshot =  'snapscript_03122015_174427_222_5617';
# Version (in this case, MySQL 5.6.17)
my $version = '5617';
# PITR datetime
my $pitr = '2016-02-13_09:23:34';
my $pitr_past = '2014-02-13_09:23:34';
my $pitr_close = '2015-12-03_17:44:30';

subtest 'check_time' => sub {
        ok(DBOD::Storage::NetApp::Snapshot::is_valid($snapshot, $pitr, $version), 'Valid date pair');
        ok(DBOD::Storage::NetApp::Snapshot::is_valid($snapshot . '_cold', $pitr, $version), 'Cold snapshot');
        ok(!DBOD::Storage::NetApp::Snapshot::is_valid($snapshot . '_cold', $pitr_close, $version), 'Cold snapshot, PITR too close');
        ok(!DBOD::Storage::NetApp::Snapshot::is_valid($snapshot, $pitr_past, $version), 'Invalid date pair');
};

done_testing();

