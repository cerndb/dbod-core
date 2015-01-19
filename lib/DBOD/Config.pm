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

my $config_file = Config::General->new( $filename->{'PATH'} );
%cfg = $config_file->getall();
$config = \%cfg;

1;
