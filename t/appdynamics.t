#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;

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
$appdynamics{aeskey} = 'aeskey';

my %dbtype = ();
$dbtype{db_user} = 'db_username';
$dbtype{db_password} = 'db_password';

$config{pg} = \%dbtype;
$config{mysql} = \%dbtype;
$config{appdynamics} = \%appdynamics;
my $conf = \%config;

my %metadata = ();
$metadata{host} = ['hostname'];
$metadata{port} = '1234';
$metadata{subcategory} = 'MYSQL';

my $data = \%metadata;

subtest 'is_enabled' => sub {
        $mock_db->mock('do', sub {return 1;});
        ok(DBOD::Appdynamics::is_enabled('testserver', $conf->{appdynamics}),
            'is_enabled: true');
        $mock_db->mock('do', sub {return 0;});
        ok(!DBOD::Appdynamics::is_enabled('testserver', $conf->{appdynamics}),
            'is_enabled: false');
    };

subtest 'disable' => sub {
        $mock_db->mock('do', sub {return 1;});
        ok(DBOD::Appdynamics::disable('testserver', $conf->{appdynamics}),
            'disable: SUCCESS');
        $mock_db->mock('do', sub {return 0;});
        ok(!DBOD::Appdynamics::disable('testserver', $conf->{appdynamics}),
            'disable: FAIL');
    };

subtest 'enable' => sub {
        print Dumper $data;
        $mock_db->mock('do', sub {return 1;});
        ok(DBOD::Appdynamics::enable('testserver', $conf, $data),
            'enable: SUCCESS');
        $mock_db->mock('do', sub {return 0;});
        ok(!DBOD::Appdynamics::enable('testserver', $conf, $data),
            'enable: FAIL');
    };
done_testing();

