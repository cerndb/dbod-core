use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::PG');

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

# Initialization

use DBOD::Runtime;

my $rt = DBOD::Runtime->new();
my @lines = <DATA>;
$rt->write_file_arr('/tmp/pg_ctl', \@lines);
chmod 0755, '/tmp/pg_ctl';

my $metadata = {
    datadir => "/ORA/dbs03/PGTEST/data",
    bindir => "/tmp",
    socket => "/var/lib/pgsql",
    port => '6600',
};

my $config = {
    pgsql => {
        db_user => 'dod_mysql',
        db_password => 'password',
    },
};

my $pg = DBOD::PG->new(
    instance => 'pgtest',
    metadata => $metadata,
    config => $config,
);

# Check status
ok(!$pg->is_running(), 'check_state');

# Stop
ok($pg->stop(), 'stop');

$pg->_connect_db();
isa_ok($pg->db(), 'DBOD::DB', 'db connection object OK');

done_testing();

__DATA__
#!/bin/bash
exit 0
