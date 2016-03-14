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

my $metadata = { datadir => "/ORA/dbs03/PGTEST/data",
    bindir => "/tmp" };

my $pg = DBOD::PG->new(
    instance => 'pgtest',
    metadata => $metadata,
);

# Check status
ok(!$pg->is_running(), 'check_state');

# Stop
ok($pg->stop(), 'stop');

done_testing();

__DATA__
#!/bin/bash
exit 0
