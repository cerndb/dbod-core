#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;

SKIP: {
    require_ok 'DBOD::Storage::NetApp::ZAPI';
}

use DBOD::Storage::NetApp::ZAPI;

done_testing();

