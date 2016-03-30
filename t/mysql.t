use strict;
use warnings;

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
    0,1, # check_State
    0, # Start OK. Nothing to do
    1,0,1, # Start OK
    1,0,1, # Start OK. Skip networking
    1,0,0, # Start FAIL
    1, # Stop OK. Nothing to do
    0,1, # Stop OK
    0,0); # stop FAIL

# Check status
$runtime->mock('run_cmd' => sub {
        my $ret = shift @outputs;
        #DEBUG "run_cmd: " . $ret;
        return $ret;}
);

is($mysql->is_running(), $TRUE, 'check_state: RUNNING');
is($mysql->is_running(), $FALSE, 'check_state: STOPPED');

# Instance start
is($mysql->start(), $OK, 'start OK: Nothing to do');
is($mysql->start(), $OK, 'start OK');
is($mysql->start( skip_networking => 1), $OK, 'start OK. Skip networking');
is($mysql->start(), $ERROR, 'start FAIL');

# Stop
is($mysql->stop(), $OK, 'stop OK: Nothing to do');
is($mysql->stop(), $OK, 'stop OK');
is($mysql->stop(), $ERROR, 'stop FAIL');


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

my $mtab_file = File::ShareDir::dist_dir('DBOD') . '/sample_mtab';

my $buf = $mysql->_parse_err_file('PIN', $mtab_file);
ok(length $buf > 0, '_parse_err_file');


done_testing();


