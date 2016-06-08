use strict;
use warnings;
use DBOD::Config;
use Test::More;
use File::ShareDir;
use Data::Dumper;

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

use_ok('DBOD::Systems::MySQL');

# Initialization
use Test::MockModule;
use File::ShareDir;

use DBOD;

my $metadata = {
    datadir => "/ORA/dbs03/MYTEST/mysql",
    bindir => "/tmp",
    socket => "/tmp/socket",
    subcategory => 'mysql',
    port => '5500',
    version => '5.6.17',
};

my $config = {
    mysql => {
        db_user => 'dod_mysql',
        db_password => 'password',
    },
    };

my $mysql = DBOD::Systems::MySQL->new(
    instance => 'mytest',
    metadata => $metadata,
    config => $config,
);

my $runtime = Test::MockModule->new('DBOD::Runtime');

my @outputs = (
    $OK, # is_running TRUE
    $TRUE, # Start OK. Nothing to do
    $FALSE, $OK, # Stop OK
    $FALSE, $ERROR, # stop FAIL
);

my @outputs2 = (
    $ERROR, # is_running FALSE
    $TRUE, # Stop OK. Nothing to do
    $FALSE, $ERROR, $OK, # Start OK
    $FALSE, $ERROR, $OK, # Start OK. Skip networking
    $FALSE, $ERROR, $ERROR, # Start FAIL
);

$runtime->mock('run_cmd' =>
        sub {
            my %args = @_;
            my $output_ref = $args{output};
            $$output_ref = "1234 mysqld /ORA/dbs03/MYTEST/mysql\ntest";
            my $ret = shift @outputs;
            return $ret;
        });

my $mymod = Test::MockModule->new('DBOD::Systems::MySQL');
$mymod->mock('_parse_err_file' => sub {
        return "Test err file";
    });

is($mysql->is_running(), $TRUE, 'Instance is RUNNING');
is($mysql->start(), $OK, 'start OK: Nothing to do');
is($mysql->stop(), $ERROR, 'stop FAIL');
is($mysql->stop(), $OK, 'stop OK');

$runtime->mock('run_cmd' =>
    sub {
        my %args = @_;
        my $output_ref = $args{output};
        $$output_ref = "666 error";
        my $ret = shift @outputs2;
        return $ret;
    });

is($mysql->is_running(), $FALSE, 'Instance is NOT RUNNING');
is($mysql->stop(), $OK, 'stop OK: Nothing to do');
is($mysql->start(), $OK, 'start OK');
is($mysql->start( skip_networking => 1), $OK, 'start OK. Skip networking');
is($mysql->start(), $ERROR, 'start FAIL');

my @db_do_outputs = (
    1, 1,
    1, 0,
    0, 0,
);
my $db = Test::MockModule->new('DBOD::DB');
$db->mock('do' => sub {
        return shift @db_do_outputs;
    });

is($mysql->ping(), $OK, 'ping OK. Responsive');
is($mysql->ping(), $ERROR, 'ping ERROR. Unresponsive delete');
is($mysql->ping(), $ERROR, 'ping ERROR. Unresponsive insert');

$db->mock('do' => sub {
        return undef;
    });

# TODO: Fix this test
SKIP: {
    skip "ping ERROR: Unable to raise exception", 1;
    is( $mysql->ping(), $ERROR, 'ping ERROR' );
};

$mysql->_connect_db();
isa_ok( $mysql->db(), 'DBOD::DB', 'db connection object OK' );

$mymod->unmock('_parse_err_file');
$runtime->unmock('run_cmd');

my $mtab_file = DBOD::Config::get_share_dir() . '/sample_mtab';
diag Dumper $mtab_file;
my $buf = $mysql->_parse_err_file('PIN', $mtab_file);
ok(length $buf > 0, '_parse_err_file');

# snapshot testing
subtest 'snapshot' => sub {

        my @outputs = (
            $FALSE, # Error no instance running
            $TRUE, # Error no ZAPI server
            $TRUE, # Error preparing snapshot
            $TRUE, # Error flushing tables
            $TRUE, # Error flushing logs
            $TRUE, # Error unlocking tables
            $TRUE, # Error determining log sequence
            $TRUE, # Error creating snapshot
            $TRUE, # Error unlocking tables
            $TRUE, # Succesful snapshot
        );

        $mymod->mock('is_running' => sub {
                return shift @outputs;
            });

        $db->mock('select' => sub {
                my @row = ("binlog.000354",);
                my @rows = (\@row,);
                return \@rows;
            });

        my $zapi = Test::MockModule->new('DBOD::Storage::NetApp::ZAPI');

        # We start failing everything
        $zapi->mock( 'get_server_and_volname' =>
            sub {
                my @buf = (undef, undef);
                return \@buf;
            });

        $zapi->mock( 'snap_prepare' => sub { return $ERROR; });
        $zapi->mock( 'snap_create' => sub { return $ERROR; });

        is($mysql->snapshot(), $ERROR, 'Snapshot ERROR. No Instance running');
        is($mysql->snapshot(), $ERROR, 'Snapshot ERROR. No ZAPI server');
        $zapi->mock( 'get_server_and_volname' =>
            sub {
                my @buf = ("server_zapi", "volume_name");
                return \@buf;
            });
        is($mysql->snapshot(), $ERROR, 'Snapshot ERROR. Error preparing snapshot');
        $zapi->mock( 'snap_prepare' => sub { return $OK; });

        @db_do_outputs = (
            $ERROR, # Error flushing tables
            $OK, $ERROR, $ERROR,# Error flushing logs. Unlock Error
            $OK, $ERROR, $OK,# Error flushing logs. Unlock OK
            $OK, $OK, $OK,# Error creating snapshot
            $OK, $OK, $ERROR, # Error unlocking tables
            $OK, $OK, $OK, # Succesful snapshot
        );

        $db->mock('do' => sub {
                my $buf = shift @db_do_outputs;
				diag 'do: ' .  $buf;
                return $buf;
            });

        is($mysql->snapshot(), $ERROR, 'Snapshot ERROR. Error flushing tables');
        is($mysql->snapshot(), $ERROR, 'Snapshot ERROR. Error flushing logs');
        is($mysql->snapshot(), $ERROR, 'Snapshot ERROR. Error flushing logs. Unlock OK');
        is($mysql->snapshot(), $ERROR, 'Snapshot ERROR. Error creating snapshot');
        $zapi->mock( 'snap_create' => sub { return $OK; });
        is($mysql->snapshot(), $ERROR, 'Snapshot completed. Error unlocking tables');
        is($mysql->snapshot(), $OK, 'Snapshot OK');

    };

subtest 'restore' => sub {
        is($mysql->restore(), $ERROR, 'Restore without snapshot ERROR');
        my $snapshot = 'test_snap';
        my $pit = 'pit date';
        is($mysql->restore($snapshot), $OK);
        is($mysql->restore($snapshot, $pit), $OK);
};

done_testing();


