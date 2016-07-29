use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;
use Log::Log4perl;

# Check logger is not inizialized before the config module is in use
ok(!Log::Log4perl->initialized(), 'logger not initialized OK');

# Check logger is properly instantiated
use_ok('DBOD::Config');
ok(Log::Log4perl->initialized(), 'logger initialized OK');


done_testing();
