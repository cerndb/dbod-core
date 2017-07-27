#!/usr/bin/perl
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Test::More;
use Test::MockModule;
use Test::Output;
use Test::MockObject::Extends;
use DBOD;
use File::ShareDir;
use Getopt::Long;

use_ok('DBOD::Systems::InfluxDB');
use_ok('DBOD::Network::Api');
use_ok('DBOD::Config');

BEGIN { Log::Log4perl->easy_init( {
    level  => $DEBUG,
    layout => "%d %p (%c:%L)> %m%n"
});
};

my $filename = DBOD::Config::get_share_dir()."/influxdb_entity_example.json";

my $cache = DBOD::Network::Api::load_cache($filename);
note( Dumper $cache );

my $instancename = "my_influx";
my $metadata = $cache->{$instancename};

my $config = {
    influxdb => {
        host => 'db-test',
        port => '8886',
    },
    common => {
        upgrade_folder => ''
    }
};

my $influxdb = DBOD::Systems::InfluxDB->new({
    instance => $instancename,
    metadata => $metadata,
    config   => $config,
});

my $runtime = Test::MockModule->new('DBOD::Runtime');



####################
# is_running() tests
####################
$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};
        if ($args{cmd} =~ /status/i) {
            $$output_ref = "Process is not running [ FAILED ]";
            return $ERROR;
        }
    });

ok(!$influxdb->is_running(), "Test instance is not runnning" );

$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};
        if ($args{cmd} =~ /status/i) {
            $$output_ref = "Process is running [ OK ]";
            return $OK;
        }
    });

ok($influxdb->is_running(), "Test instance is running");

$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};
        if ($args{cmd} =~ /status/i) {
            $$output_ref = undef;
            return $ERROR;
        }
    });

stdout_like {$influxdb->is_running()} qr/CMD OUTPUT: undef/,
    "Test undef output when running cmd";

####################
# start() tests
####################
$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};

        if ($args{cmd} =~ /status/i) {
            $$output_ref = "Process is not running [ FAILED ]";
            return $ERROR;
        }
        if ($args{cmd} =~ /start/i) {
            $$output_ref = "Starting the process influxdb [ OK ]\ninfluxdb process was started [ OK ]";
            return $OK;
        }
        return undef;
    });

is($influxdb->start(), $OK, 'Test start instance when is it not running');

$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};

        if ($args{cmd} =~ /status/i) {
            $$output_ref = "Process is not running [ FAILED ]";
            return $ERROR;
        }
        if ($args{cmd} =~ /start/i) {
            $$output_ref = "Starting the process influxdb [ OK ]\ninfluxdb process cannot be started [ FAILED ]";
            return $ERROR;
        }
        return undef;
    });

is($influxdb->start(), $ERROR, "Test ERROR to start instance");

$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};

        if ($args{cmd} =~ /status/i) {
            $$output_ref = "Process is running [ OK ]";
            return $OK;
        }
    });

is($influxdb->start(), $OK, 'Test start instance when it is already running');


####################
# stop() tests
####################
$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};

        if ($args{cmd} =~ /status/i) {
            $$output_ref = "Process is running [ OK ]";
            return $OK;
        }
        if ($args{cmd} =~ /stop/i) {
            $$output_ref = "process was stopped [ OK ]";
            return $OK;
        }
        return undef;
    });

is($influxdb->stop(), $OK, 'Test stop instance when it is running');

$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};

        if ($args{cmd} =~ /status/i) {
            $$output_ref = "Process is running [ OK ]";
            return $OK;
        }
        if ($args{cmd} =~ /stop/i) {
            $$output_ref = "process cannot be stopped [ FAILED ]";
            return $ERROR;
        }
        return undef;
    });

is($influxdb->stop(), $ERROR, 'Test error when stopping instance');

$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};

        if ($args{cmd} =~ /status/i) {
            $$output_ref = "Process is not running [ FAILED ]";
            return $ERROR;
        }
    });

is($influxdb->stop(), $OK, 'Tets stop instance when it is not running');


####################
# ping() tests
####################
my $useragent = Test::MockModule->new('LWP::UserAgent');
$useragent->mock('request' =>
    sub {
        return HTTP::Response->new('204', 'No Content');
    });
$useragent->mock('get' =>
    sub {
        return HTTP::Response->new('200', 'OK', [ 'Content-Type' => 'application/json' ],
            '{"results":[{"series":[{"name":"dbod_ping","columns":["time","status"],"values":[["1970-01-01T00:00:01.464254505Z",0]]}]}]}');
    });
is($influxdb->ping(), $OK, 'Tets ping with write_point=ok and instance is up');

$useragent->mock('request' =>
    sub {
        return HTTP::Response->new('204', 'No Content');
    });
$useragent->mock('get' =>
    sub {
        return HTTP::Response->new('200', 'OK', [ 'Content-Type' => 'application/json' ], '{"results":[{}]}');
    });
is($influxdb->ping(), $ERROR, 'Tets ping with write=ok, query=error, instance is up');

$useragent->mock('request' =>
    sub {
        return HTTP::Response->new('204', 'No Content');
    });
$useragent->mock('get' =>
    sub {
        return HTTP::Response->new('400', 'Bad Request', [ 'Content-Type' => 'application/json' ],
            '{"error":"error parsing query: found time, expected ; at line 1, char 48"}');
    });
is($influxdb->ping(), $ERROR, 'Tets ping with write=ok, query=error, instance is up');

$useragent->mock('request' =>
    sub {
        return HTTP::Response->new('404', 'Not Found');
    });
# Mock the query returning OK to ensure the process fails when writting the point
$useragent->mock('get' =>
    sub {
        return HTTP::Response->new('200', 'OK');
    });
is($influxdb->ping(), $ERROR, 'Tets ping with write=error');

$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};
        if ($args{cmd} =~ /status/i) {
            $$output_ref = "Process is running [ OK ]";
            return $OK;
        }
    });


####################
# snapshot() tests
####################
subtest 'snapshot' => sub {

        my $zapi = Test::MockModule->new('DBOD::Storage::NetApp::ZAPI');

        # We start failing everything
        $zapi->mock( 'get_server_and_volname' =>
            sub {
                my @buf = (undef, undef);
                return \@buf;
            });

        $zapi->mock( 'snap_prepare' => sub { return $ERROR; });
        $zapi->mock( 'snap_create' => sub { return $ERROR; });
        is($influxdb->snapshot(), $ERROR, 'Snapshot ERROR. No Instance running');
        is($influxdb->snapshot(), $ERROR, 'Snapshot ERROR. No ZAPI server');

        $zapi->mock( 'get_server_and_volname' =>
            sub {
                my @buf = ("server_zapi", "volume_name");
                return \@buf;
            });
        is($influxdb->snapshot(), $ERROR, 'Snapshot ERROR. Error preparing snapshot');

        $zapi->mock( 'snap_prepare' => sub { return $OK; });
        is($influxdb->snapshot(), $ERROR, 'Snapshot ERROR. Error creating snapshot');

        $zapi->mock( 'snap_create' => sub { return $OK; });
        is($influxdb->snapshot(), $OK, 'Snapshot OK');

    };

subtest 'upgrade' => sub {
        $influxdb->upgrade_folder(DBOD::Config::get_share_dir()."/upgrades/");
        $influxdb = Test::MockObject::Extends->new($influxdb);

        $influxdb->set_false('is_running');
        $influxdb->set_always('stop', $OK);
        $influxdb->set_always('snapshot', $OK);
        $influxdb->set_always('start', $OK);
        $runtime->mock('run_cmd' => sub { return $OK;});

        my $upgrade_version = '1.3.0';

        is($influxdb->upgrade($upgrade_version), $ERROR, 'Upgrade not completed when the instance is not running');
        is($influxdb->upgrade('fake.version'), $ERROR, 'Upgrade script not found');

        $influxdb->set_always('stop', $ERROR);
        $influxdb->set_true('is_running');
        is($influxdb->upgrade($upgrade_version), $ERROR, 'Upgrade not completed when ERROR stopping the instance');

        $influxdb->set_always('stop', $OK);
        is($influxdb->upgrade($upgrade_version), $OK, 'Upgrade completed with instance running OK');

        $influxdb->set_always('snapshot', $ERROR);
        is($influxdb->upgrade($upgrade_version), $ERROR, 'Upgrade not completed when ERROR making snapshot');

        $influxdb->set_always('snapshot', $OK);
        $runtime->mock('run_cmd' => sub { return $ERROR;});
        is($influxdb->upgrade($upgrade_version), $ERROR, 'Upgrade not completed when ERROR applying upgrade script');

        $runtime->mock('run_cmd' => sub { return $OK;});
        $influxdb->set_always('start', $ERROR);
        is($influxdb->upgrade($upgrade_version), $ERROR, 'Upgrade not completed when ERROR starting the instance');
    };

done_testing();

