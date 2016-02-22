package DBOD::CRS;
use strict;
use warnings FATAL => 'all';

use Log::Log4perl qw(:easy);

#Returns the state of a CRS resource (if the state is undef CRS is not installed or the resource does not exist)
sub get_resource_state {
    my ($self, $resource, $oracle_crs) = @_;
    my ($rc, @output, $state);

    INFO "Parameters resource: <$resource> oracle_crs: <$oracle_crs>";

    $rc = $self->RunStr(
        "$oracle_crs status resource $resource | grep STATE | awk -F\"=\" '{print \$2}' | awk '{print \$1}'",
        \@output );

    if ($rc) {
        $state = $output[0];
        if (defined $state) {
            chomp $state;
        }
        DEBUG "Resource is in <$state>";
        return $state;
    }
    else {
        DEBUG "Error getting CRS resource state!";
        return;
    }
}

sub start_resource {
    my ($self, $resource, $oracle_crs) = @_;
    my ($cmd, $rc, @output);

    INFO "Parameters resource: <$resource> oracle_crs: <$oracle_crs>";

    DEBUG "Checking CRS resource state.";
    my ($state) = $self->get_CRS_resource_state( $resource, $oracle_crs );
    if (defined $state) {
        #If instance is CRS and UNKNOWN
        if ($state eq "UNKNOWN") {
            ERROR "The instance is in UNKNOWN state! Please check.";
            return 0; #not ok
        }
        #If instance is CRS and INTERMEDIATE
        if ($state eq "INTERMEDIATE") {
            ERROR "The instance is in INTERMEDIATE state! Please check.";
            return 0; #Not ok
        }
        #If instance is CRS and ONLINE
        if ($state eq "ONLINE") {
            DEBUG "The instance was running. Nothing to do.";
            return 1; #ok
        }
        #If instance is CRS adn OFFLINE
        if ($state eq "OFFLINE") {
            $cmd = "$oracle_crs start resource $resource";
            $rc = $self->RunStr( $cmd, \@output );
            DEBUG join( "", @output );
            if ($rc) {
                DEBUG "CRS resource is up";
                return 1; #ok
            } else {
                ERROR "Problem starting CRS resource. Please check.";
                return 0; #notok
            }
        }
        ERROR "CRS state $state is not a valid state.";
        return 0; #not ok
    }
    else {
        ERROR "StartCRSResource: Given CRS resource was not found. Please check.";
        return 0; #not ok
    }
}

sub stop_resource {
    my ($self, $resource, $oracle_crs) = @_;
    INFO "Parameters resource: <$resource> oracle_crs: <$oracle_crs>";

    my ($cmd, $rc, @output);
    ERROR "Checking CRS resource state.";
    my ($state) = &get_CRS_resource_state( $resource, $oracle_crs );
    if (defined $state) {
        #If instance is CRS and UNKNOWN
        if ($state eq "UNKNOWN") {
            ERROR "The instance is in UNKNOWN state! Please check.";
            return 0; #notok
        }
        #If instance is CRS and INTERMEDIATE
        if ($state eq "INTERMEDIATE") {
            ERROR "The instance is in INTERMEDIATE state! Please check.";
            return 0; #notok
        }
        #If instance is CRS and OFFLINE
        if ($state eq "OFFLINE") {
            ERROR "The instance was not running. Nothing to do.";
            return 1; #ok
        }
        #If instance is CRS adn ONLINE
        if ($state eq "ONLINE") {
            $cmd = "$oracle_crs stop resource $resource";
            $rc = $self->RunStr( $cmd, \@output );
            DEBUG join( "", @output );
            if ($rc) {
                DEBUG "MySQL instance is down";
                return 1; #ok
            } else {
                ERROR "Problem stopping MySQL instance. Please check.";
                return 0; #notok
            }
        }
        ERROR "CRS state $state is not a valid state.";
        return 0; #not ok
    }
    else {
        ERROR "Given CRS resource was not found. Please check.";
        return 0; #not ok
    }
}


1;