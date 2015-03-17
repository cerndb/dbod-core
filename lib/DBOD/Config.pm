package DBOD::Config;

use strict;
use warnings;
use Exporter;

use Config::General;
use YAML::Syck;
use File::ShareDir;
use Log::Log4perl;

our ($VERSION, @ISA, @EXPORT_OK, $config, %cfg, $logger_cfg);

$VERSION     = 0.1;
@ISA         = qw(Exporter);
@EXPORT_OK   = qw( $config %cfg );

my $share_dir = File::ShareDir::dist_dir('DBOD');
my $filename = LoadFile( "$share_dir/configpath.conf" );

my $config_file = Config::General->new( 
    -ConfigFile => "${share_dir}/dbod-core.conf-template", 
    -ForceArray => 1); # Allows 1 element ARR

%cfg = $config_file->getall();
$config = \%cfg;

1;
