use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

use_ok('DBOD::MySQL');

# Initialization

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

# Check status
ok(!$mysql->is_running(), 'check_state');

# Stop
ok(!$mysql->stop(), 'stop');

$mysql->_connect_db();
isa_ok($mysql->db(), 'DBOD::DB', 'db connection object OK');

my $mtab_file = File::ShareDir::dist_dir('DBOD') . '/sample_mtab';

my $buf = $mysql->parse_err_file('PIN', $mtab_file);
ok(length $buf > 0, 'parse_err_file');


done_testing();


