use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

use_ok('DBOD::MySQL');

# Initialization

use DBOD::Runtime;

my $metadata = {
    datadir => "/ORA/dbs03/MYTEST/mysql",
    bindir => "/tmp",
    socket => "/tmp/socket",
};

my $mysql = DBOD::MySQL->new(
    instance => 'mytest',
    metadata => $metadata,
);

# Check status
ok(!$mysql->is_running(), 'check_state');

# Stop
ok(!$mysql->stop(), 'stop');

done_testing();


