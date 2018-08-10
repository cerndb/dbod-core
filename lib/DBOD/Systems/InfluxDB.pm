# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Systems::InfluxDB;

use strict;
use warnings;

use Moose;
with 'DBOD::Instance';

use Data::Dumper;
use File::Basename;
use POSIX qw(strftime);

use DBOD;
use DBOD::Runtime;
use DBOD::Storage::NetApp::ZAPI;

use URI;
use LWP::UserAgent;
use REST::Client;
use JSON;

has 'service_script' => (is => 'rw', isa => 'Str');
has 'upgrade_folder' => (is => 'rw', isa => 'Str');


sub BUILD {

	my $self = shift;

    $self->log->debug("Instance: " . $self->instance);
    $self->log->debug("Datadir: " . $self->metadata->{datadir});
    $self->log->debug("Socket: " . $self->metadata->{port});

    $self->service_script("sudo /sbin/service dbod-" . $self->instance);
    $self->upgrade_folder($self->config->{'common'}->{'upgrade_folder'} . '/influxdb/');
	return;
};


sub is_running {
    my $self = shift;
    $self->log->debug("Checking if InfluxDB instance is running");

    my ($output, @buf);
    my $cmd = $self->service_script . " status";
    my $error = DBOD::Runtime::run_cmd(
        cmd => $cmd,
        output => \$output);

    #if output is not defined print literal 'undef'
    $output //= 'undef';
    $self->log->debug("CMD OUTPUT: " . $output);

    if ($error) {
        $self->log->debug("Instance is DOWN");
        return $FALSE;
    } else {
        $self->log->debug("Instance is UP");
        return $TRUE;
    }
}

sub _connect_db {
    # Not needed for influxdb
    ...
}

sub ping {
    my $self = shift;

    my $browser = LWP::UserAgent->new();

    my @hosts = @{$self->metadata->{hosts}};
    my $host = $hosts[0];
    my $port = $self->metadata->{port};
    my $service_uri = "https://" . $host . ":" . $port;

    # Write test point with current timestamp
    $self->log->debug("Timestamp Write");
    my $write_uri = $service_uri . "/write?db=dbmon";
    my $timestamp = time;
    my $testpoint = "dbod_ping status=0 " . $timestamp;
    my $write_request = HTTP::Request->new( 'POST', $write_uri );
    $write_request->authorization_basic(
        $self->config->{influx}->{db_user},
        $self->config->{influx}->{db_password},
        );
    $write_request->content($testpoint);
    
    my $write_response = $browser->request($write_request);
    #Successful writes will return a 204 HTTP Status Code
    if ($write_response->code != 204) {
        $self->log->error("Error contacting instance");
        $self->log->error(Dumper $write_response);
        return $ERROR;
    }

    #Now query the just inserted point
    $self->log->debug("Timestamp Query");
    my $full_uri = URI->new($service_uri . '/query');
    $full_uri->query_form({
            "db" => "dbmon",
            "q"  => "SELECT status FROM dbod_ping WHERE time = " . $timestamp
        });
    $self->log->debug(Dumper $full_uri);
    my $query = HTTP::Request->new( 'GET', "$full_uri");
    $query->authorization_basic(
        $self->config->{influx}->{db_user},
        $self->config->{influx}->{db_password},
        );
    
    my $query_response = $browser->request($query);

    # The query is executed successfully returns code 200
    if ($query_response->code != 200) {
        $self->log->error($query_response->content);
        return $ERROR;
    }

    #Check now the content returns the expected point
    my $results = decode_json $query_response->content;
    my $rows = $results->{'results'}[0]; #return the hash reference
    # count the number of keys, if empty then through error
    $self->log->debug(Dumper $full_uri);
    if (scalar(keys %{$rows}) == 0) { 
        $self->log->error($query_response->content);
        return $ERROR;
    }

    # Delete point
    $self->log->debug("Timestamp Delete");
    $full_uri = URI->new($service_uri . '/query');
    $full_uri->query_form({
            "db" => "dbmon",
            "q"  => "DELETE FROM dbod_ping WHERE time = " . $timestamp
        });
    $self->log->debug(Dumper $full_uri);
    $query = HTTP::Request->new( 'GET', "$full_uri");
    $query->authorization_basic(
        $self->config->{influx}->{db_user},
        $self->config->{influx}->{db_password},
        );
    
    $query_response = $browser->request($query);

    # The query is executed successfully returns code 200
    if ($query_response->code != 200) {
        $self->log->error($query_response->content);
        return $ERROR;
    }

    # if the rest of the checks have passed then return ok
    return $OK;
}

sub start {
    my ($self, %args) = @_;
    $self->log->debug("Starting up InfluxDB instance");

    if ($self->is_running()) {
        $self->log->debug("Nothing to do");
        return $OK;
    }
    else{
        my $cmd = $self->service_script . " start";
        my $error = DBOD::Runtime::run_cmd( cmd => $cmd );
        if ($error) {
            $self->log->error("Problem starting InfluxDB instance. Please check.");
            return $ERROR;
        } else {
            $self->log->debug("InfluxDB instance started correctly");
            return $OK;
        }
    }
}


sub stop {

    my ($self) = @_;
    $self->log->debug("Stopping InfluxDB instance");

    if ($self->is_running()) {
        my ($cmd, $error);
        #Put the instance down
        $self->log->debug("Shutting down");
        $cmd = $self->service_script . ' stop';
        $error = DBOD::Runtime::run_cmd( cmd => $cmd);
        if ($error) {
            $self->log->error("Problem shutting down InfluxDB instance. Please check.");
            return $ERROR; #not ok
        } else  {
            $self->log->debug("Shutdown completed");
            return $OK;
        }
    }
    else{
        $self->log->error("Nothing to do.");
        return $OK;
    }
}

# This function is being implemented by Jon
sub snapshot {
    my $self = shift;

    if (! $self->is_running()) {
        $self->log->error("Snapshotting requires a running instance");
        return $ERROR;
    }
    
    # Get ZAPI server
    my $zapi = DBOD::Storage::NetApp::ZAPI->new(config => $self->config());

    my $arref = $zapi->get_server_and_volname($self->metadata->{datadir});

    my ($server_zapi, $volume_name) = @{$arref};

    if ((! defined $server_zapi) || (! defined $volume_name)) {
        $self->log->error("Error generating ZAPI server");
        return $ERROR;
    }

    # Snapshot preparation
    my $rc = $zapi->snap_prepare($server_zapi, $volume_name);
    if ($rc == $ERROR) {
        $self->log->error("Error preparing snapshot");
        return $ERROR;
    }

    # Create name tag
    my $timetag = strftime "%d%m%Y_%H%M%S", gmtime;
    my $version = $self->metadata->{version};
    $version =~ tr/\.//d;
    my $snapname = "snapscript_" . $timetag . "_" . $version;

    # Create snapshot
    $rc = $zapi->snap_create($server_zapi, $volume_name, $snapname);
    my $errorflag = 0;
    if ($rc == $ERROR ) {
        $errorflag = $ERROR;
        $self->log->error("Error creating snapshot");
    }

    if ($errorflag) {
        $self->log->error("Please check: snapshot was not properly taken.");
        return $ERROR;
    } else {
        $self->log->debug("Snapshot operation successful");
        return $OK;
    }
}


sub upgrade {
    my $self = shift;
    my ($upgrade_version) = @_;

    my $version = $self->metadata->{version};
    my $entity = $self->metadata->{db_name};
    my $result;

    $self->log->debug(sprintf("Executing upgrade on %s from version %s to %s", $entity, $version, $upgrade_version));

    # Find upgrade script
    my $upgrade_script = sprintf("%sinfluxdb_from_%s_to_%s", $self->upgrade_folder, $version, $upgrade_version);
    if (! -e $upgrade_script)
    {
        $self->log->error(sprintf("Upgrade script %s not found from version %s to %s", $upgrade_script, $version, $upgrade_version));
        return $ERROR;
    }

    my $upgrade_wrapper = sprintf("%sinfluxdb_upgrade_wrapper.sh", $self->upgrade_folder);
    if (! -e $upgrade_wrapper)
    {
        $self->log->error(sprintf("Wrapper script %s not found", $upgrade_wrapper));
        return $ERROR;
    }

    if (! $self->is_running()) {
        $self->log->error("Instance is not running. Upgrades requires a running instance");
        return $ERROR;
    }

    $result = $self->snapshot();
    if ($result != $OK) {
        $self->log->error("Problem making snapshop of InfluxDB instance. Please check.");
        return $ERROR;
    }

    $result = $self->stop();
    if ($result != $OK) {
        $self->log->error("Problem shutting down InfluxDB instance. Please check.");
        return $ERROR;
    }

    $ENV{'INFLUXDB_CURRENT_VERSION'} = $version;
    $ENV{'INFLUXDB_NEXT_VERSION'} = $upgrade_version;
    $ENV{'INFLUXDB_ENTITY'} = $entity;
    $ENV{'INFLUXDB_UPGRADE_FOLDER'} = $self->upgrade_folder;

    my $cmd = sprintf("sudo -E %s", $upgrade_wrapper);

    my ($output, @buf);
    my $cmd_error = DBOD::Runtime::run_cmd(
        cmd => $cmd,
        output => \$output);
    if ($cmd_error) {
        $self->log->error("Problem appliying the upgrade script. Please check.");
        return $ERROR;
    }
    $self->log->debug("Applied upgrade script");

    $result = $self->start();
    if ($result != $OK) {
        $self->log->error("Problem starting up InfluxDB instance. Please check.");
        return $ERROR;
    }

    return $OK;
}

1;
