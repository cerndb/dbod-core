# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD;

use strict;
use warnings;
use base 'Exporter';
use Readonly;

our ($VERSION, @EXPORT_OK, $ERROR, $OK);

$VERSION = 0.70;

Readonly $ERROR => 1;
Readonly $OK => 0;

@EXPORT_OK   = qw( $ERROR $OK );

1;
