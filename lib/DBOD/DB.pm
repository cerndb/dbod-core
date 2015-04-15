#!/usr/bin/env perl
# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::DB;

use strict;
use warnings;

use Moose;
with 'MooseX::Log::Log4perl';
with 'MooseX::Role::DBIx::Connector' => {
    connection_name => 'db',
};

use Try::Tiny;

sub run_sql_file {
    my ($self, $filename) = @_;
    try{
        open my $fh, '<', $filename or do {
            $self->log->error("Can't open SQL File for reading: $!");
            return;
            };
        local $/;
        my $sql =  <$fh>;
        try {
            $self->db_conn->do($sql);
            return;
        } catch {
            $self->log->error("An error ocurred executing SQL file: $!");
            return;
        };
    }
    catch {
        $self->log->error("An error ocurred reading $filename: $!");
        return;
    }
}

sub db_run {
    my ($self, $statement, $bind_values);
    $self->db_conn->prepare($statement);
    $self->db_conn->execute(@{$bind_values});
    return $self->db_conn->fetchall_arrayref();
}

1;
