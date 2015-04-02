package DBOD::Config;

use strict;
use warnings;
use Exporter;

use Config::General;
use YAML::Syck;
use File::ShareDir;
use Log::Log4perl;
use JSON;

our ($VERSION, @ISA, @EXPORT_OK, $config, $metadata, $logger_cfg);

$VERSION     = 0.1;
@ISA         = qw(Exporter);
@EXPORT_OK   = qw( $config %cfg $metadata);

my $share_dir = File::ShareDir::dist_dir('DBOD');
my $filename = LoadFile( "$share_dir/configpath.conf" );

my $config_file = Config::General->new( 
    -ConfigFile => "${share_dir}/dbod-core.conf-template", 
    -ForceArray => 1); # Allows 1 element ARR

sub _load_cache {
    my $filename = shift;
    my $json_text = do { 
        local $/ = undef;
        open(my $json_fh, "<:encoding(UTF-8)", $filename)
            or return ();
        <$json_fh>
    };
    my $nested_array = decode_json $json_text;
    my @flat_array = map{@$_} @$nested_array;

    return @flat_array;
}
# Reads configuration to make it available
my %cfg = $config_file->getall();
$config = \%cfg;

# Loads entity/host entities metadata
my %hcache = _load_cache($config->{'api'}->{'cachefile'});
$metadata = \%hcache;

1;
