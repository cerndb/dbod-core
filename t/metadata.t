use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::Api');

use DBOD::Api qw(get_entity_metadata);

my $metadata = get_entity_metadata('unexistant');
isa_ok($metadata, 'HASH', 'metadata');

done_testing();
