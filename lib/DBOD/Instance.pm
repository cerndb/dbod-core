# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Instance;
# This package defines an abstract instance class to be subclassed by type:
#   e.g: MySQL, PG, Oracle, ...

use strict;
use warnings FATAL => 'all';
use Log::Log4perl qw (:easy);
use Data::Dumper;

our $VERSION = 0.68;
use Moose;
use MooseX::ABC;
with 'MooseX::Log::Log4perl';

use DBOD::DB;

## Input
has 'instance' => ( is => 'ro', isa => 'Str', required => 1);
has 'metadata' => (is => 'rw', isa => 'HashRef', required => 1);
has 'config' => (is => 'ro', isa => 'HashRef');
has 'db' => (is => 'rw', isa => 'Object');

# Class methods
## Public;
requires 'is_running'; # Checks status of server process
requires 'start'; # Starts instance server
requires 'stop'; # Stops instance server
#requires 'snapshot'; # Perform a consistent snapshot
#requires 'recover'; # Recovers the instance datafiles from a snapshot to a PIT
#requires 'upgrade'; # Upgrades the datafiles and running server of the instance

## Private
requires '_connect_db';
# Initializes the $instance->db object with the connection parameters of the
# job target instance

1;