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
use Test::MockModule;

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

my $runtime = Test::MockModule->new('DBOD::Runtime');

my @outputs = (
    0,1, # check_State
    0,1, # start OK
    1, # start OK. Nothing to do
    0,0, # start FAIL
    0, # Stop OK. Nothing to do
    1,1, # Stop OK
    1,0,
    1,0); # Stop FAIL

# Check status
$runtime->mock('run_cmd' => sub {
        my $ret = shift @outputs;
        #DEBUG "run_cmd: " . $ret;
        return $ret;}
    );

ok(!$pg->is_running(), 'check_state STOPPED');
ok($pg->is_running(), 'check_state RUNNING');

# Instance start
ok($pg->start(), 'start OK');
ok($pg->start(), 'start OK: Nothing to do');
ok(!$pg->start(), 'start FAIL');

# Stop
ok($pg->stop(), 'stop OK: Nothing to do');
ok($pg->stop(), 'stop OK');
ok(!$pg->stop(), 'stop FAIL');

$pg->_connect_db();
isa_ok($pg->db(), 'DBOD::DB', 'db connection object OK');

done_testing();

__DATA__
#!/bin/bash
exit 0
