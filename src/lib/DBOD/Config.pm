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

our ($VERSION, @ISA, @EXPORT_OK);

$VERSION     = 0.1;
@ISA         = qw(Exporter);
@EXPORT_OK   = qw( load );


sub load {
    my $share_dir = File::ShareDir::dist_dir('DBOD');
    my $filename = LoadFile( "$share_dir/configpath.conf" );

    my $config_file = Config::General->new( 
        -ConfigFile => $filename->{'PATH'}, 
        -ForceArray => 1); # Allows 1 element ARR

    my %cfg = $config_file->getall();
    return \%cfg; 
}

1;
