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

use Data::Dumper;
use Try::Tiny;

sub execute_sql_file {
    my ($self, $filename) = @_;
    try{
        open my $fh, '<', $filename or do {
            $self->log->error("Can't open SQL File for reading: $!");
            return;
            };
        try {
            # local $/=';';
            my @statements = <$fh>;
            foreach my $statement (@statements) {
                $self->log->debug("Executing: ${statement}");
                $self->db_conn->dbh->do($statement);
            }
            return 0;
        } catch {
            $self->log->error(
                sprintf("An error ocurred executing SQL file:\n%s:%s", 
                    $self->db_conn->dbh->err,
                    $self->db_conn->dbh->errstr));
            return $self->db_conn->dbh->err;
        };
    }
    catch {
        $self->log->error("An error ocurred reading $filename: $!");
        return;
    }
}

sub select {
    my ($self, $statement, $bind_values) = @_;
    $self->log->debug("Running SQL statement: " . $statement);
    try {
        if (defined $bind_values) {
            return $self->db_conn->dbh->selectall_arrayref($statement, @{$bind_values});
            }
        else {
            return $self->db_conn->dbh->selectall_arrayref($statement);
        }
    } catch {
        $self->log->error(
            sprintf("An error ocurred executing SQL statement:\n%s:%s", 
                $self->db_conn->dbh->err,
                $self->db_conn->dbh->errstr));
        return $self->db_conn->dbh->err;
    };
}

sub do {
    my ($self, $statement, $bind_values) = @_;
    $self->log->debug("Running SQL statement: " . $statement);
    try {
        if (defined $bind_values) {
            return $self->db_conn->dbh->do($statement, undef, @{$bind_values});
            }
        else {
            return $self->db_conn->dbh->do($statement,);
        }
    } catch {
        $self->log->error(
            sprintf("An error ocurred executing SQL sttatement:\n%s:%s", 
                $self->db_conn->dbh->err,
                $self->db_conn->dbh->errstr));
        return $self->db_conn->dbh->err;
    };
}

1;
