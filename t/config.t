use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::Config');

use DBOD::Config qw($config $metadata);

isa_ok($config, 'HASH');
isa_ok($metadata, 'HASH');

my $share_dir = File::ShareDir::dist_dir('DBOD');
my $filename = "$share_dir/test.json";

note( "filename is $filename" );
my %test = DBOD::Config::_load_cache($filename);
note( Dumper \%test );

isa_ok(\%test, 'HASH');
ok(exists $test{'a'});
ok(exists $test{'c'});
is($test{'b'}{'prop1'}, 'value1');

done_testing();
