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
        return undef;
    });

# TODO: Fix this test
SKIP: {
    skip "ping ERROR: Unable to raise exception", 1;
    is( $pg->ping(), $ERROR, 'ping ERROR' );
};

$pg->_connect_db();
isa_ok($pg->db(), 'DBOD::DB', 'db connection object OK');

done_testing();

__DATA__
#!/bin/bash
exit 0
