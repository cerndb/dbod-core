# Copyright (C) 2015, CERN
# # This software is distributed under the terms of the GNU General Public
# # Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# # In applying this license, CERN does not waive the privileges and immunities
# # granted to it by virtue of its status as Intergovernmental Organization
# # or submit itself to any jurisdiction.

package DBOD::Config;

use strict;
use warnings;
use Exporter;

use Config::General;
use YAML::Syck;
use File::ShareDir;
use Log::Log4perl;

our ($VERSION, @EXPORT_OK);

$VERSION     = 0.67;
use base qw(Exporter);
@EXPORT_OK   = qw( load );

# Initializes Log4Perl 
BEGIN {
    my $share_dir = File::ShareDir::dist_dir('DBOD');
    Log::Log4perl::init( "${share_dir}/logger.conf" );
}

sub load {
    # Loads configuration file and returns a reference to a configuration
    # hash
    my $share_dir = File::ShareDir::dist_dir('DBOD');
    my $filename = LoadFile( "$share_dir/configpath.conf" );
   
    my $config_file;
    if ( -f $filename->{'PATH'}) {
        # If a system configuration file exist on the expected
        # location we load it
        $config_file = Config::General->new( 
        -ConfigFile => $filename->{'PATH'}, 
        -ForceArray => 1); # Allows 1 element ARR
    } else {
        # Otherwise we load the example template (i.e. for testing)
        $config_file = Config::General->new( 
        -ConfigFile => "${share_dir}/dbod-core.conf-template", 
        -ForceArray => 1); # Allows 1 element ARR
    }
    
    my %cfg = $config_file->getall();
    return \%cfg; 
}

1;
