use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::Systems::PG');

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

# Initialization

use DBOD;
use DBOD::Runtime;
use Test::MockModule;

my @lines = <DATA>;
DBOD::Runtime::write_file_arr('/tmp/pg_ctl', \@lines);
chmod 0755, '/tmp/pg_ctl';

my $metadata = {
    datadir => "/ORA/dbs03/PGTEST/data",
    bindir => "/tmp",
    socket => "/var/lib/pgsql",
    port => '6600',
    version => '9.4.5'
};

my $config = {
    pgsql => {
        db_user => 'dod_mysql',
        db_password => 'password',
    },
};

my $pg = DBOD::Systems::PG->new(
    instance => 'pgtest',
    metadata => $metadata,
    config => $config,
);

my $runtime = Test::MockModule->new('DBOD::Runtime');

my @outputs = (
    1,0, # check_State STOPPED/RUNNING
    0,0, # start OK
    1, # start OK. Nothing to do
    1,1, # start FAIL
    0, # Stop OK. Nothing to do
    0,0, # Stop OK
    1, # Stop FAIL
    1,0,0,0,0,0,0); # Snapshot
# Check status
$runtime->mock('run_cmd' => sub {
        my $ret = shift @outputs;
        #DEBUG "run_cmd: " . $ret;
        return $ret;}
    );

is($pg->is_running(), $FALSE,  'check_state STOPPED');
is($pg->is_running(), $TRUE, 'check_state RUNNING');

# Instance start
is($pg->start(), $OK, 'start OK');
is($pg->start(), $OK, 'start OK: Nothing to do');
is($pg->start(), $ERROR, 'start FAIL');

# Stop
is($pg->stop(), $OK, 'stop OK: Nothing to do');
is($pg->stop(), $OK, 'stop OK');
is($pg->stop(), $ERROR, 'stop FAIL');

my @db_do_outputs = (
    1, 1,
    1, 0,
    0, 0,
);
my $db = Test::MockModule->new('DBOD::DB');
$db->mock('do' => sub {
        return shift @db_do_outputs;
    });

is($pg->ping(), $OK, 'ping OK. Responsive');
is($pg->ping(), $ERROR, 'ping ERROR. Unresponsive delete');
is($pg->ping(), $ERROR, 'ping ERROR. Unresponsive insert');

$db->mock('do' => sub {
        return 0;
    });

# TODO: Fix this test
SKIP: {
    skip "ping ERROR: Unable to raise exception", 1;
    is( $pg->ping(), $ERROR, 'ping ERROR' );
};

$pg->_connect_db();
isa_ok($pg->db(), 'DBOD::DB', 'db connection object OK');

# snapshot testing
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

        is($pg->snapshot(), $ERROR, 'Snapshot ERROR. No Instance running');
        is($pg->snapshot(), $ERROR, 'Snapshot ERROR. No ZAPI server');
        $zapi->mock( 'get_server_and_volname' =>
            sub {
                my @buf = ("server_zapi", "volume_name");
                return \@buf;
            });
        is($pg->snapshot(), $ERROR, 'Snapshot ERROR. Error preparing snapshot');
        $zapi->mock( 'snap_prepare' => sub { return $OK; });

        @db_do_outputs = (
            0, # Error setting up backup mode
            1, 1,# Error creating snapshot
            1, 0,# Error stopping backup mode
            1, 1, # OK
        );

        $db->mock('do' => sub {
                my $buf = shift @db_do_outputs;
                return $buf;
            });

        is($pg->snapshot(), $ERROR, 'Snapshot ERROR. Error setting DB in backup mode');

        is($pg->snapshot(), $ERROR, 'Snapshot ERROR. Error creating snapshot');
        $zapi->mock( 'snap_create' => sub { return $OK; });

        is($pg->snapshot(), $ERROR, 'Snapshot ERROR. Error stopping backup mode');

        is($pg->snapshot(), $OK, 'Snapshot OK');

    };

subtest 'restore' => sub {
		use Test::MockObject;
		use DBOD::Config;
		my $snapshot =  'snapscript_03122015_174427_222_5617';
		my $pit = '2016-02-13_09:23:34';
        
		is($pg->restore(), $ERROR, 'Restore without snapshot ERROR');
        my $mtab_file = DBOD::Config::get_share_dir() . '/sample_mtab';
        my $mntpoint = '/ORA/dbs03/PINOCHO';
        my $regex = "^(.*?dbnas[\\w-]+):(.*?)\\s+($mntpoint)\\s+nfs";
		# Mocking ZAPI methods
		my $zapi_mock = Test::MockModule->new('DBOD::Storage::NetApp::ZAPI');
		my $server_zapi = Test::MockObject->new();
		$zapi_mock->mock('get_server_and_volname' => sub { 
				my @array = ($server_zapi, $mntpoint);
				return \@array;
			});
        is($pg->restore($snapshot), $ERROR, 'Restore missing binary logs');
		# Mock list of binary logs
		my $pgmod = Test::MockModule->new('DBOD::Systems::MySQL');
		$pgmod->mock('_list_binary_logs' => sub {
				my @array = ('binlog.000222', 'binlog.000223', 'binlog.000224');
				return \@array;
			});
		$zapi_mock->mock('snap_restore' => sub { return $ERROR } );
        is($pg->restore($snapshot), $ERROR, 'snap_estore fail');
		$zapi_mock->mock('snap_restore' => sub { return $OK } );
		# Succesful restore
        is($pg->restore($snapshot), $OK, 'Restore successful');
};

done_testing();

__DATA__
#!/bin/bash
exit 0
