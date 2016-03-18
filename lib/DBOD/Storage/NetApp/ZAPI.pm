# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Storage::NetApp::ZAPI;

use strict;
use warnings;

our $VERSION = 0.68;

# uncoverable statement
use lib '/opt/netapp-manageability-sdk-5.3.1/lib/perl/NetApp'; 

use Moose;
with 'MooseX::Log::Log4perl';

has 'config' => (is => 'ro', isa => 'HashRef');

use Try::Tiny;
use DBOD::Runtime;
use Data::Dumper;

use NaServer; # uncoverable statement
use NaElement; # uncoverable statement

use Socket;

sub _host_ip {
    my $servername = shift;
    return inet_ntoa(inet_aton($servername));
}

my $runtime = DBOD::Runtime->new;

sub create_server {
    my ($self, $ipaddr, ,$username, $password, $vserver, $version) = @_;
    $self->log->info("Parameters ipaddr: <$ipaddr> username: $username password: not displayed");
    $self->log->info("Parameters vserver: <$vserver>") if defined $vserver;
    $self->log->info("Parameters version: <$version>") if defined $version;

    if (! defined $version) {
        $version="21"; # default C-mode
    }
    my $server = NaServer->new($ipaddr, 1, $version);
    my $resp= $server->set_style("LOGIN");
    if ($resp->isa("NaElement") && $resp->results_errno != 0) {
        my $r = $resp->results_reason();
        $self->log->error("Setting LOGIN returns error: $r");
        return 0;
       } 
    $server->set_port(443);
    $resp= $server->set_admin_user($username, $password);

    if ($resp->isa("NaElement") && $resp->results_errno != 0) {
         my $r = $resp->results_reason();
         $self->log->error("Setting username and password returns error: $r");
        return 0;
    }
    $resp = $server->set_transport_type("HTTPS");
    if ($resp->isa("NaElement") && $resp->results_errno != 0) {
        my $r = $resp->results_reason();
        $self->log->error("Unable to set HTTPS: $r");
        return 0;
    }
    if (defined $vserver) {
        $resp = $server->set_vserver($vserver);
        if ($resp->isa("NaElement") && $resp->results_errno != 0) {
            my $r = $resp->results_reason();
            $self->log->error("Setting vserver returns error: $r");
            return 0;
        }
    }
    return $server;

}    

sub is_Cmode_mount() {
    my ($self, $mountpoint) = @_;
    $self->log->info("Checking mountpoint: <$mountpoint>");
    my($iscmode)=0;
    if ($mountpoint =~ m{\/vol\/(.*)$}x) {
        $iscmode = 0;
        $self->log->debug("We are working with a 7-mode volume <$mountpoint>");
    } else {
        $self->log->debug("We are working with a C-mode volume <$mountpoint>");
        $iscmode = 1;
    }
    return $iscmode;
} 

#Get Mount points following a regex C-mode, hash: controler -> (mountpoint2, mountpoint2,...) 
sub get_mount_point_NAS_regex {
    my ($self, $regex, $exclusion_list)=@_;
    $self->log->info("Parameters regex: <$regex>");
    $self->log->info("Parameters: exclusion_list: <$exclusion_list>") if defined $exclusion_list;
    my ($output, %pairsfsnas, $rc);
    $rc = $runtime->run_str("cat /etc/mtab", \$output);
    my @lines = split /\n/, $output;
    if ($rc) {
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ m{$regex}x ) {
                $self->log->debug("match in line <$line> ");
                my ($nas, $mountpath, $filesystemmount);
                $nas = $1;
                $mountpath = $2;
                $filesystemmount = $3;
                $self->log->debug("Got controller <$nas> mountpath controller: <$mountpath> file system: <$filesystemmount>");

                if (defined $exclusion_list && scalar(@$exclusion_list) > 0 
                    && FindInArray($filesystemmount,$exclusion_list)) {
                        $self->log->debug("Controller <$nas> mountpath controller: <$mountpath> file system: <$filesystemmount> in exclusion list");
                    next;
                }
                if (exists $pairsfsnas{$1}) {
                    push @{$pairsfsnas{$1}} ,$2;
                } else {
                    $pairsfsnas{$1} = [ $2 ];
                }
            }
        }
    }
    $self->log->debug("result: " . Dumper \%pairsfsnas );
    return \%pairsfsnas;
}

# server object, array of mount points to look for. $aggrinfo if set it will also retrieve aggregate values
sub get_volinfo_Cmode {
    my($self, $server,$volname,$aggrinfo)=@_;
    $self->log->info("Parameters volname: <$volname>, aggrinfo: <$aggrinfo>");
    #build query
    my($nelem,$query,$volpath,$volpath_parent);
    my($autosize, $autosizemax, $autoincrement, $total_size,
        $used_size,$aggregate,$isOnautosize,$name,$vservername,$volstate);
    $autoincrement=0; #not enabled
    if (! defined $aggrinfo) {
        $aggrinfo=1; #get aggregate information
    }
    $self->log->debug("Working with volume: <$volname>");
    my $tag=""; #for iterations
    while (defined($tag)) {
        $nelem = NaElement->new("volume-get-iter");
        if ($tag ne "") {
                $nelem->child_add_string("tag", $tag);
            }
        $nelem->child_add_string("max-records",10);

        #Build the query
        $query = NaElement->new("query");
        $volpath_parent = NaElement->new("volume-attributes");
        $volpath = NaElement->new("volume-id-attributes");
        my(@arr)= split '/',$volname;
        if (scalar(@arr) >=2) { #it's a mount point
            $volpath->child_add_string("junction-path", $volname);
        } else { #it's volume name
            $volpath->child_add_string("name", $volname);
        }
        $query->child_add($volpath_parent);
        $volpath_parent->child_add($volpath);
        $nelem->child_add($query);
        my $desiredAttrs = NaElement->new("desired-attributes");
        my $desiredAutoSpace = NaElement->new("volume-autosize-attributes");
        my $desiredIdAttr = NaElement->new("volume-id-attributes");
        my $desiredSpace = NaElement->new("volume-space-attributes");
        my $desiredState = NaElement->new("volume-state-attributes");
        $desiredAttrs->child_add($desiredAutoSpace);
        $desiredAttrs->child_add($desiredIdAttr);
        $desiredAttrs->child_add($desiredSpace);
        $desiredAttrs->child_add($desiredState);
        $nelem->child_add($desiredAttrs);

        #query sent to the controller
        $self->log->debug("Query looks like: \n " . $nelem->sprintf());

        my $out = $server->invoke_elem($nelem);
        if (ref ($out) eq "NaElement" && $out->results_status() eq "failed") {
            $self->log->debug("Result: " . $out->results_reason() . ", err number: " . $out->results_errno() . ", status: " . $out->results_status()  );
            return();
        }
        if (ref ($out) eq "NaElement" && $out->child_get_int("num-records") == 0) {
            $self->log->debug("No volume with name <$volname>");
                return();
        }

        $tag= $out->child_get_string("next-tag");
        my @volList = $out->child_get("attributes-list")->children_get();

        foreach my $volInfo (@volList) {

            my $volIdAttrs = $volInfo->child_get("volume-id-attributes");
            if ($volIdAttrs) {
                $name = $volIdAttrs->child_get_string("name");
                $aggregate = $volIdAttrs->child_get_string("containing-aggregate-name");
                $vservername = $volIdAttrs->child_get_string("owning-vserver-name");

            }

            my $volSizeAttrs = $volInfo->child_get("volume-space-attributes");
            if ($volSizeAttrs) {
                $total_size = $volSizeAttrs->child_get_string("size-total");
                $used_size = $volSizeAttrs->child_get_string("size-used");
                }

            my $volAutoSizeAttrs = $volInfo->child_get("volume-autosize-attributes");
            if ($volAutoSizeAttrs) {
                        $isOnautosize = $volAutoSizeAttrs->child_get_string("is-enabled");
                if ($isOnautosize eq 'true') {
                    $autosize = $isOnautosize;
                    $autosizemax = $volAutoSizeAttrs->child_get_string("maximum-size");
                    $autoincrement = $volAutoSizeAttrs->child_get_string("increment-size"); # in bytes
                } else {
                    $autosize =0;
                    $self->log->debug("RunTime.GetVolInfoCmode : no autosize enabled for vol: <$name>");
                }
                }
            my $volStateAttrs = $volInfo->child_get("volume-state-attributes");
            if ($volSizeAttrs) {
                $volstate = $volStateAttrs->child_get_string("state");
            }

        }#foreach
        $tag=undef;
        # we are just interested in the first iteration, there should be just one volume with that name, junction-path.
        #There is a changed in behaviour in Ontap 8.2.2P1. This was not needed before.
    }#while

    #Get attributes of the aggregate
    my($aggrfreesize,$aggrusedsize,$nodename);
    $aggrfreesize=0;
    $aggrusedsize=0;
    if ($aggrinfo) {
        $tag=""; #for iterations
        while (defined($tag)) {
            $nelem = NaElement->new("aggr-get-iter");
            if ($tag ne "") {
                $nelem->child_add_string("tag", $tag);
                }
            $nelem->child_add_string("max-records",10);

            #Build the query
            $query = NaElement->new("query");
            my $aggr_parent = NaElement->new("aggr-attributes");
            $query->child_add($aggr_parent);
            $aggr_parent->child_add_string("aggregate-name", $aggregate);
            $nelem->child_add($query);
            my $desiredAttrs = NaElement->new("desired-attributes");
            my $desiredSpace = NaElement->new("aggr-space-attributes");
            my $nodeid = NaElement->new("aggr-ownership-attributes"); #
            $desiredAttrs->child_add($desiredSpace);
            $desiredAttrs->child_add($nodeid); #
            $nelem->child_add($desiredAttrs);

            $self->log->debug("Query looks like: \n " . $nelem->sprintf());

            my $out = $server->invoke_elem($nelem);
            if (ref ($out) eq "NaElement" && $out->results_status() eq "failed") {
                $self->log->debug("Reason: " . $out->results_reason() . ", err number: " .
                        $out->results_errno() . ", status: " . $out->results_status() );
                return();
            }
            if (ref ($out) eq "NaElement" && $out->child_get_int("num-records") == 0) {
                $self->log->debug("No volume with name <$volname>");
                    return();
            }
            $tag= $out->child_get_string("next-tag");
            my @aggrList = $out->child_get("attributes-list")->children_get();

            foreach my $aggrInfo (@aggrList) {
                my $aggrSizeAttrs = $aggrInfo->child_get("aggr-space-attributes");
                if (defined $aggrSizeAttrs ) {
                    $aggrusedsize = $aggrSizeAttrs->child_get_string("size-used"); # in bytes
                    $aggrfreesize= $aggrSizeAttrs->child_get_string("size-available"); # in bytes
                    }
                my $nodeidinfo = $aggrInfo->child_get("aggr-ownership-attributes");
                if (defined $nodeidinfo) {
                    $nodename=$nodeidinfo->child_get_string("owner-name");
                }
                }
        }
    }
    my %vol_info_cmode = ( "name" => $name,
               "autosize_enabled" => $autosize,
               "max_autosize" => $autosizemax,
               "size_used" => $used_size,
               "size_total" => $total_size,
               "aggr_name" => $aggregate,
               "aggr_size_used" => $aggrusedsize,
               "aggr_size_free" => $aggrfreesize,
               "autosize_increment" => $autoincrement,
               "vserver" => $vservername,
               "node" => $nodename,
               "state" => $volstate
            );
 
       $self->log->debug("Final result " . Dumper \%vol_info_cmode );
    return \%vol_info_cmode;
}



#it returns an array of vserver + volname. It's used for snapshots operations. If there is a problem an undef will be return.
sub get_server_and_volname {
    my($self, $mntpoint)=@_;
    $self->log->info("Parameters mntpoint: <$mntpoint>");

    my $nasmounts = $self->get_mount_point_NAS_regex("^(.*?dbnas[\\w-]+):(.*?)\\s+($mntpoint)\\s+nfs");
    if (! scalar keys %$nasmounts) { #we should get 1 entry
        $self->log->debug("No mount points return. This makes no sense. We cant proceed.");
        return [undef,undef];
    }
    my($iscmode)=0;
    my($server_zapi,$rc,$volume_name);
    if ( scalar (keys(%$nasmounts)) == 1 ) {
        while ( my ($controller, $mountpoint) = each(%$nasmounts) ) {
            $controller =~ s/\.cern\.ch//g;  #remove domain
            $self->log->debug("Working with controller <$controller> and mountpoint: <@$mountpoint>");
            if (scalar(@$mountpoint) > 1) {
                $self->log->debug("Too many mount points:");
                $self->log->debug("Values of mountpoint variable: " . Data::Dumper->Dump($mountpoint));
                return [undef,undef];
            }

            my $ipcluster = _host_ip($controller);
            $server_zapi = $self->create_server_from_mount_point($controller, $$mountpoint[0],0); # I connect to the data lif not the cluster-mgmt
            if ($server_zapi == 0) {
                $self->log->debug("Server Zapi was not created.");
                return [undef,undef];
            }
            if ( $self->is_Cmode_mount( $$mountpoint[0]) == 0) {
                $volume_name=$self->GetVolumeName7modeFromMount($$mountpoint[0]);
                $iscmode=0;
                chomp $volume_name;
                $self->log->debug("We are working with a 7-mode volume <$volume_name> on <$$mountpoint[0]>");
            } else {
                $self->log->debug("Preparing query, we are working with a C-mode volume <$$mountpoint[0]>");
                $volume_name= $$mountpoint[0];
                $iscmode=1;
            }
        }
    } else {
        $self->log->debug("Too many mount points return < " . scalar (keys(%$nasmounts)) . ">. This makes no sense. We cant proceed.");
        return [undef,undef];
    }

    if ($iscmode) {
        $rc = $self->get_volinfo_Cmode($server_zapi,$volume_name,0);  # last parameter is 0 as we cant get access to aggregate information
        if ($rc==0) {
            $self->log->debug("Error retrieving info.!");
            return [undef,undef];
        }
        $volume_name = $rc->{"name"};
        $self->log->debug("Working with C-mode volume: <$volume_name>");
    } else {
        $rc = $self->GetVolInfo7mode($server_zapi,$volume_name,"true");
        if ($rc == 0 ) {
            $self->log->debug("Error retrieving info.!");
            return [undef,undef];
        }
    }
    return [$server_zapi ,$volume_name];
}

sub create_server_from_mount_point {
    my($self, $controller,$mount_point,$admin) = @_;
    $self->log->info("Parameters controller: <$controller>, mount_point: <$mount_point>, admin: <$admin>");
    my $arref = $self->get_auth_details($controller,$mount_point,$admin);
    my($controller_mgmt,$ipcluster,$user_storage,$password_nas,$server_version,$server);

    if (defined $arref) {
        $user_storage=$$arref[0];
        $password_nas=$$arref[1];
        $server_version=$$arref[2];
        $ipcluster=$$arref[3];
    } else {
        $self->log->error("No password to connect to NAS defined!");
        return; #not ok
    }

    $server = $self->create_server($ipcluster,$user_storage,$password_nas,undef,$server_version);
    return $server;
}

#it returns an array with [user, password, server_version, ipcluster] credentials
sub get_auth_details {
    my($self, $controller, $mount_point, $admin) = @_;
    $self->log->info("Parameters controller: <$controller>, mount_point: <$mount_point>, admin: <$admin>");
    my($controller_mgmt, $ipcluster,
        $user_storage, $password_nas, $server_version);
    if ($controller =~ m{^[\D]+\-([\d\w]+)}x) {
        $controller = $1;
    } elsif ($controller =~ m{([\d\w]+)\-[\D]+}x) {
        $controller = $1;
    }
    $self->log->debug("Controller match: <$controller>");
    $self->log->debug('We are working with a C-mode volume <' . $mount_point . '>');
    if ($admin) {
        $user_storage = "admin";
        $controller_mgmt = $controller . '-cluster-mgmt';
        $ipcluster = _host_ip($controller_mgmt);
    } else {
        $user_storage = "vsadmin";
        $ipcluster = _host_ip($controller);
    }
    $password_nas = $self->config->{filers}->{password};
    unless (defined $password_nas) {
        $self->log->error("No password to connect to NAS defined!");
        return 0; #not ok
    }
    $server_version = 17;
    $self->log->debug("Returning: $user_storage, XXXXXX, $server_version, $ipcluster");
    return [$user_storage, $password_nas, $server_version, $ipcluster];
} 

sub snap_clone {
    my($self,$server_zapi,$volume_name,$snapshot,$junction)=@_;
    $self->log->info("Parameters server_zapi: not displayed, volume_name: <$volume_name>");
    $self->log->info("Parameters snapshot: <$snapshot>") if defined $snapshot;
    $self->log->info("Parameters junction-path: <$junction>") if defined $junction;


    my($suffix)= `date +%d%m%Y%H%M%S`;
    chomp $suffix;
    my($newvol)= $volume_name . $suffix . "clone";
    my($newjunction) = $junction;

    $self->log->debug("Trying to create new volume name: <$newvol> and new junction path: <$newjunction>");

    my($isCmode);
    if ($junction =~ m{^\/vol\/}x) {
        $isCmode=0;
    } else {
        $isCmode=1;
    }
    my $api = NaElement->new('volume-clone-create');
    if ($isCmode) {
        $api->child_add_string('junction-active','true');
        $api->child_add_string('junction-path',$newjunction);
    }
    if (defined $snapshot) {
        $api->child_add_string('parent-snapshot',$snapshot);
    }
    $api->child_add_string('parent-volume',$volume_name);
#$api->child_add_string('space-reserve','true');
#$api->child_add_string('use-snaprestore-license','<use-snaprestore-license>');
    $api->child_add_string('volume',$newvol);

    my $output = $server_zapi->invoke_elem($api);
    if (defined ($self->check_API_call($output))) {
                my $r = $output->results_reason();
                $self->log->error("volume-clone-create failed: $r");
                return; #error
        } else {
                $self->log->debug("Cloned successfully new volume name: <$newvol> and new junction path: <$newjunction>!!");
                return "$newvol:$newjunction"; #ok
        }
}

sub snap_create {
    my($self,$server_zapi,$volume_name,$create)=@_;
    $self->log->info("Parameters server_zapi: not displayed, volume_name: <$volume_name>, create: <$create>");

    my $output = $server_zapi->invoke("snapshot-create",
            "volume", $volume_name,
            "snapshot", $create);

    if (defined ($self->check_API_call($output))) {
        my $r = $output->results_reason();
        $self->log->debug("snapshot-create failed: $r");
        return 0; #error
    } else {
        $self->log->debug("Created!!");
        return 1; #ok
    }
}

sub snap_restore {
    my($self,$server_zapi,$volume_name,$restore)=@_;
    $self->log->info("Parameters server_zapi: not displayed, volume_name: <$volume_name>, restore: <$restore>");

    my $output = $server_zapi->invoke("snapshot-restore-volume",
            "volume", $volume_name,
            "snapshot", $restore);

    if (defined ($self->check_API_call($output))) {
        my $r = $output->results_reason();
        $self->log->debug("snapshot-restore-volume failed: $r");
        return 0; #error
    } else {
        $self->log->debug("Volume <$volume_name> has been restored using snapshot <$restore>!!");
        return 1; #ok
    }
}

sub snap_list {
    my($self,$server_zapi,$volume_name)=@_;
    $self->log->info("Parameters server_zapi: not displayed, volume_name: <$volume_name>");

    my $output = $server_zapi->invoke("snapshot-list-info", "volume", $volume_name);
    my @arr_snaps=();
    if (defined ($self->check_API_call($output))) {
        $self->log->debug("Error retrieving list info.!");
        return @arr_snaps;
    }

    #
    # get snapshot list
    #
    my $snapshotlist = $output->child_get("snapshots");
    if (!defined($snapshotlist) || ($snapshotlist eq "")) {
        # no snapshots to report
        $self->log->debug("No snapshots on volume $volume_name");
        return @arr_snaps;
    }
    my @snapshots = $snapshotlist->children_get();
    foreach my $ss (@snapshots) {
        my $accesstime = $ss->child_get_int("access-time", 0);
        my $total = $ss->child_get_int("total", 0);
        my $cumtotal =   $ss->child_get_int("cumulative-total", 0);

        my $busy = ($ss->child_get_string("busy") eq "true");

        my $dependency = $ss->child_get_string("dependency");
        my $name = $ss->child_get_string("name");

        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=POSIX::localtime($accesstime);
        my $date = POSIX::strftime("%a %b %e %H:%M:%S %Y",$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

        push @arr_snaps,[$name,$accesstime,$busy,$total,$cumtotal,$dependency];
    }
    return @arr_snaps;
}

sub snap_prepare {
    my($self,$server_zapi,$volume_name,$num)=@_;
    $self->log->info("Parameters server_zapi: not displayed, volume_name: <$volume_name>, num: <$num>");

    my ($rc);
    $self->log->debug("Getting snapshots for <$volume_name>");
    my(@arr_snaps) = $self->snap_list($server_zapi,$volume_name);
    if (@arr_snaps == 0) {
        $self->log->debug("Error retrieving number of snapshots for <$volume_name> or no snapshots at ll.!");
        return 1; #ok
    } else {
        $self->log->debug(" There are <". scalar(@arr_snaps) . "> in this volume: <$volume_name>!");
    }
    if (scalar(@arr_snaps) > $num) { #we need to delete some snapshots
        my($tobedeleted) = scalar(@arr_snaps) - $num ;
        $self->log->debug("<$tobedeleted> need to be deleted to meet threshold <$num>.");
        for (my $i=$tobedeleted; $i > 0; $i--) {
            my($snapinfoscalar)= shift @arr_snaps; #get the first one. it's the oldest
            my(@snapinfo) = @$snapinfoscalar;
            $self->log->debug("Trying to delete: < $snapinfo[0] > on volume: <$volume_name>.!");
            $rc=$self->snap_delete($server_zapi,$volume_name ,$snapinfo[0]);
            if ($rc == 0 ) {
                $self->log->debug("Error deleting snapshot: <" . $snapinfo[0] . "> on volume: <$volume_name>.!");
                return 0; #not ok
            }  else {
                $self->log->debug("Success deleting snapshot: <" . $snapinfo[0] . "> on volume: <$volume_name>.!");
            }
        }
    }
    return 1; #ok
}

sub snap_delete {
    my ($self, $server_zapi, $volume_name, $delete) = @_;
    $self->log->info("Deleting volume_name: <$volume_name>, delete: <$delete>");

    my $output = $server_zapi->invoke("snapshot-delete",
            "volume", $volume_name,
            "snapshot", $delete);

    if (defined ($self->check_API_call($output))) {
        my $r = $output->results_reason();
        $self->log->error("snapshot-delete failed: $r");
        return 0; #error

    } else {
        $self->log->debug("Deleted!!");
        return 1; #ok
    }
}
 
sub check_API_call(){
    my ($self, $api_call)=@_;
    if ($api_call->results_errno != 0){
            my $reason = $api_call->results_reason();
            my $errno = $api_call->results_errno();
            $self->log->debug("NetAPP API error #($errno), msg: $reason");
            return $errno;
    }
    return;
}

1;
