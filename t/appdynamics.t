#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use_ok('DBOD::Appdynamics');

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

use Test::MockObject;
use Test::MockModule;

use DBOD::Runtime;
my $mock_db = Test::MockModule->new('DBOD::DB');

my %config = ();
my %appdynamics = ();
$appdynamics{'host'} = 'appd-server.cern.ch';
$appdynamics{'user'} = "APPD-USER";
$appdynamics{'password'} = "XXXXXXXXX";
$appdynamics{'port'} = '3306';
$config{appdynamics} = \%appdynamics;

my $conf = \%config;

subtest 'is_enabled' => sub {
        $mock_db->mock('do', sub {return 1;});
        ok(DBOD::Appdynamics::is_enabled('testserver', $conf->{appdynamics}),
            'is_enabled: true');
        $mock_db->mock('do', sub {return 0;});
        ok(!DBOD::Appdynamics::is_enabled('testserver', $conf->{appdynamics}),
            'is_enabled: false');
    };


done_testing();

