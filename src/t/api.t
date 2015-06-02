use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::Api');

use DBOD::Api qw(load_cache get_entity_metadata);

my $metadata = get_entity_metadata('unexistant');
isa_ok($metadata, 'HASH', 'metadata');

my $share_dir = File::ShareDir::dist_dir('DBOD');
my $filename = "$share_dir/test.json";
my %config = ();
my %api = ();
$api{'cachefile'} = "$share_dir/test.json";
$config{'api'} = \%api;

note( "%config is " . Dumper \%config );
my %test = load_cache(\%config);
note( Dumper \%test );

isa_ok(\%test, 'HASH');
ok(exists $test{'a'});
ok(exists $test{'c'});
is($test{'b'}{'prop1'}, 'value1');

done_testing();

