use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

use_ok('DBOD::MySQL');

# Initialization
use Test::MockModule;
use File::ShareDir;

my $metadata = {
    datadir => "/ORA/dbs03/MYTEST/mysql",
    bindir => "/tmp",
    socket => "/tmp/socket",
    subcategory => 'mysql',
};

my $config = {
    mysql => {
        db_user => 'dod_mysql',
        db_password => 'password',
    },
    };

my $mysql = DBOD::MySQL->new(
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

ok($mysql->is_running(), 'check_state: RUNNING');
ok(!$mysql->is_running(), 'check_state: STOPPED');

# Instance start
ok($mysql->start(), 'start OK: Nothing to do');
ok($mysql->start(), 'start OK');
ok($mysql->start( skip_networking => 1), 'start OK. Skip networking');
ok(!$mysql->start(), 'start FAIL');

# Stop
ok($mysql->stop(), 'stop OK: Nothing to do');
ok($mysql->stop(), 'stop OK');
ok(!$mysql->stop(), 'stop FAIL');

$mysql->_connect_db();
isa_ok($mysql->db(), 'DBOD::DB', 'db connection object OK');

my $mtab_file = File::ShareDir::dist_dir('DBOD') . '/sample_mtab';

my $buf = $mysql->_parse_err_file('PIN', $mtab_file);
ok(length $buf > 0, '_parse_err_file');


done_testing();


