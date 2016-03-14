use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::PG');

use Log::Log4perl qw(:easy);
BEGIN { Log::Log4perl->easy_init() };

done_testing();
