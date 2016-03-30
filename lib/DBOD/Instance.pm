# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Instance;

use strict;
use warnings FATAL => 'all';
use Log::Log4perl qw (:easy);
use Data::Dumper;

use Moose::Role;
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

## Private
requires '_connect_db';
# Initializes the $instance->db object with the connection parameters of the
# job target instance

package DBOD::Instance::Factory;
use MooseX::AbstractFactory;

implementation_does [ qw( DBOD::Instance ) ];
implementation_class_via sub { 'DBOD::Systems::' . shift };


1;