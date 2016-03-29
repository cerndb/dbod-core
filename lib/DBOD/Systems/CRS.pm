package DBOD::Systems::CRS;
use strict;
use warnings FATAL => 'all';

use Log::Log4perl qw(:easy);

#Returns the state of a CRS resource (if the state is undef CRS is not installed or the resource does not exist)
sub get_resource_state {
    my ($resource, $oracle_crs) = @_;
    my ($rc, $output, $state);

    INFO "Resource: <$resource> oracle_crs: <$oracle_crs>";
    my $rt = DBOD::Runtime->new();
    $rc = $rt->run_str(
        "$oracle_crs status resource $resource | grep STATE | awk -F\"=\" '{print \$2}' | awk '{print \$1}'",
        \$output );
    if ($rc) {
        $state = $$output;
        DEBUG $output;
        if (defined $state) {
            chomp $state;
        }
        DEBUG "Resource <$resource> in <$state> state";
        return $state;
    }
    else {
        DEBUG "Error getting CRS resource state!";
        return;
    }
}


#TODO: The following two methods are mostly the same logic. This can be refactored
# into a single method with a command parameter (start, stop)

sub start_resource {
    my ($resource, $oracle_crs) = @_;
    my ($cmd, $rc, @output);
    INFO "Resource: <$resource> oracle_crs: <$oracle_crs>";
    my $state = get_resource_state( $resource, $oracle_crs );
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
            my $rt = DBOD::Runtime->new();
            $rc = $rt->run_str( $cmd, \@output );
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
        ERROR "CRS resource was not found. Please check.";
        return 0; #not ok
    }
}

sub stop_resource {
    my ($resource, $oracle_crs) = @_;
    INFO "Resource: <$resource> oracle_crs: <$oracle_crs>";
    my ($cmd, $rc, @output);
    my $state = get_resource_state( $resource, $oracle_crs );
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
            my $rt = DBOD::Runtime->new();
            $cmd = "$oracle_crs stop resource $resource";
            $rc = $rt->run_str( $cmd, \@output );
            if ($rc) {
                DEBUG "Resource is down";
                return 1; #ok
            } else {
                ERROR "Problem stopping Resource. Please check.";
                return 0; #notok
            }
        }
        ERROR "CRS state $state is not a valid state.";
        return 0; #not ok
    }
    else {
        ERROR "CRS resource was not found. Please check.";
        return 0; #not ok
    }
}


1;