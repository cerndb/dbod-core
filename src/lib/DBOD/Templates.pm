# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package Templates;

use warnings;
use strict;
use Exporter;

use DBOD::Ldap;
use Data::Dumper;

use Log::Log4perl qw(:easy);

use base qw(Exporter);

my $entity_template = {
    MYSQL    => 'dbod_template_mysql',
    PG => 'dbod_template_postgresql',
    ORA   => 'dbod_template_oracle',
    tnsnames   => 'dbod_template_con',
    };

my $subcategory_attributes = {
    'MYSQL' => {
        'SC-BASEDIR-LOCATION' => "/usr/local/mysql/mysql-#VERSION#",
        'SC-BINDIR-LOCATION' => "/usr/local/mysql/mysql-#VERSION#/bin",
        'SC-BINLOG-LOCATION' => "/ORA/dbs02/#DBNAME#/mysql",
        'SC-DATADIR-LOCATION' => "/ORA/dbs03/#DBNAME#/mysql", },
    'PG' => {
        'SC-BASEDIR-LOCATION' => "/usr/local/pgsql/pgsql-#VERSION#",
        'SC-BINDIR-LOCATION' => "/usr/local/pgsql/pgsql-#VERSION#/bin",
        'SC-ARCHIVEDIR-LOCATION' => "/ORA/dbs02/#DBNAME#/archive",
        'SC-XLOGDIR-LOCATION' => "/ORA/dbs02/#DBNAME#/pg_xlog",
        'SC-DATADIR-LOCATION' => "/ORA/dbs03/#DBNAME#/data",  },
    };

sub timestamp_entity {
    # Adds a timestampt with the last modification time to the 
    # SC-COMMENT attribute
    my ($conn, $entity_name) = @_;
    my $base = "SC-ENTITY=$entity_name,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DBOD::Ldap::modify_attributes($conn, $base, 
        ['SC-COMMENT' => 'Entity Modified @(' . localtime(time) . ')']);
    return;
}

sub substitute_template_dns {
    # Renames an entity
    my ($entries, $entity_name) = @_;
    for my $entity(@{$entries}) {
        my $dn = $entity->dn();
        $dn =~ s/\#ENTITY\#/$entity_name/g; 
        $entity->dn($dn);
    }
    return;
}

sub get_hosts {
    # Returns and array of LDAP::Entry's with the list of hosts an entity is hosted on
    my ($conn, $entity) = @_;
    my $hosts_base = "SC-HOSTS=hosts,SC-ENTITY=$entity," .
             "SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    return DBOD::Ldap::get_entity($conn, $hosts_base);
}

sub get_nfs_volumes {
    # Returns and array of LDAP::Entry's with the list of volumes an entity is using
    my ($conn, $entity) = @_;
    my $volumes_base = "SC-NFS-VOLUMES=nfs-volumes,SC-ENTITY=$entity," .
             "SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    return DBOD::Ldap::get_entity($conn, $volumes_base);
}

sub set_nfs_volume_host_refs {
    # Sets the desired value for SC-NFS-VOLUME-HOST-REF
    my ($conn, $entity, $nhosts) = @_;
    my $volumes = get_nfs_volumes($conn, $entity);
    my @host_refs = ();
    for (my $c = 1; $c <= $nhosts; $c++) {
        push @host_refs, $c;
    }
    # Remove Extra Volumes ID from volumes 
    for my $volume (@{$volumes}) {
        my $dn = $volume->dn();
    	if ($dn =~ /SC-NFS-VOLUME-ID/) {
            my $mesg = $conn->modify($volume->dn,
                replace => {'SC-NFS-VOLUME-HOST-REF' => [@host_refs]});
	        $mesg->code && die $mesg->error; 
		    }
        }
	return;
}

sub set_crs {
    # Adds CRS specific attributes to an entity template
    my ($conn, $new_entity) = @_;
    my $entity = "dod_" . lc $new_entity->{'dbname'};
    my $entity_address_base = "SC-ENTITY=$entity,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";

    DBOD::Ldap::add_attributes($conn, $entity_address_base, 
        ['SC-DB-CRS-REFERENCE' => $new_entity->{'crs'} ,
         'SC-RMAN-TDPO-NODE' => $new_entity->{'port'},
         'SC-RMAN-COMMAND-DIR' => $new_entity->{'socket'}, ]);
    
    # Deletes host entries from single instance template
    my $temphosts = get_hosts($conn, $entity);
    for my $host (@{$temphosts}) {
        if ($host->dn() =~ /SC-HOST-ID/) {
            my $mesg = $conn->delete($host);
            $mesg->code && die $mesg->error; 
		    }
        }
    
    # Fetch list of hosts from CRS cluster definition entity
    my $hosts = get_hosts($conn, $new_entity->{'crs'});
    # Add hosts to entity
    for my $host (@{$hosts}) {
        my $dn = $host->dn();
        $dn =~ s/$new_entity->{'crs'}/$entity/g; 
        $host->dn($dn);
    	if ($dn =~ /SC-HOST-ID/) {
	        $host->add( 'SC-TNS-LISTENER-NAME' => $new_entity->{'socket'});
        	my $mesg = $conn->add($host);
	        $mesg->code && die $mesg->error; 
            $mesg = $conn->modify($host->dn,
                replace => {'SC-ACTIVE-HOST-ALIAS' => [$new_entity->{'ip_alias'}]});
            $mesg->code && die $mesg->error;
		    }
        }
    
    set_nfs_volume_host_refs($conn, $entity, scalar(@{$hosts}) -1);
    
	return;
}

sub create_instance {
    # Creates a new entry on the LDAP by filling appropiate values on a template.
    my ($new_entity, $conf_ref) = @_;
    DEBUG 'Creating LDAP entity: ' . Dumper $new_entity;
    # Hash unpacking, for readability
    my $dbname = $new_entity->{'dbname'};
    my $port = $new_entity->{'port'};
    my $socket = $new_entity->{'socket'};
    my $subcategory = $new_entity->{'subcategory'};
    my $type = $new_entity->{'type'};
    my $hostname = $new_entity->{'hostname'};
    my $ip_alias = $new_entity->{'ip_alias'};
    my $serverdata = $new_entity->{'serverdata'};
    my $serverlogs = $new_entity->{'serverlogs'};
    my $version = $new_entity->{'version'};
    my $buffer = $new_entity->{'buffer'};
    my $crs = $new_entity->{'crs'};
    
    my $entity = "dod_" . lc($dbname);
    my $template_name = $entity_template->{$subcategory};

    my $conn = DBOD::Ldap::get_connection($conf_ref);
    # Fetches template according to Instance subcategory
    my $template_base_address = "SC-ENTITY=${template_name},SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DEBUG 'Downloading LDAP entity template: ' . $template_base_address;
    my $template = DBOD::Ldap::get_entity($conn, $template_base_address);

    for my $entry(@{$template}) {
        my $dn = $entry->dn();
        $dn =~ s/$template_name/$entity/g; 
        DEBUG 'Creating LDAP entry: ' . $dn;
        $entry->dn($dn);
        if (defined ($entry->get_value('SC-ENTITY'))) {
            $entry->replace( 'SC-ENTITY' => $entity );
        }
        DEBUG 'Adding LDAP entry: ' . Dumper $entry;
        my $mesg = $conn->add($entry);
		$mesg->code && die $mesg->error; 
    } 

    DEBUG 'Entity level parameter customization';
    my $entity_address_base = "SC-ENTITY=$entity,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DBOD::Ldap::modify_attributes($conn, $entity_address_base, 
        ['SC-DB-DATABASE-NAME' => $dbname,
         'SC-TYPE' => $type, 
         'SC-VERSION' => $version,]);
    DEBUG 'Subcategory level coustomization';
    my $attributes = $subcategory_attributes->{$subcategory};
    my $DBNAME = uc $dbname;
    while (my ($attribute, $value) = each(%{$attributes})) {
        $value =~ s/#VERSION#/$version/;
        $value =~ s/#DBNAME#/$DBNAME/;
        DBOD::Ldap::modify_attributes($conn, $entity_address_base, [ $attribute => $value ,]);
        }

    # TODO: Use buffer size parameter

    # Sets NFS Binlog server
    DEBUG 'NFS Binary logs server customization';
    my $nfs_binlogs_address_base = "SC-NFS-VOLUME-ID=1,SC-NFS-VOLUMES=nfs-volumes," .
        "SC-ENTITY=$entity,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DBOD::Ldap::modify_attributes($conn, $nfs_binlogs_address_base, 
        ['SC-NFS-VOLUME-LOCAL-PATH' => "/ORA/dbs02/" . $DBNAME,
         'SC-NFS-VOLUME-SERVER-PATH' => "/ORA/dbs02/" . $DBNAME,
         'SC-NFS-VOLUME-SERVER' => $serverlogs,]);
    
    # Sets NFS Datadir server
    DEBUG 'NFS Datadir server customization';
    my $nfs_datadir_address_base = "SC-NFS-VOLUME-ID=2,SC-NFS-VOLUMES=nfs-volumes,".
        "SC-ENTITY=$entity,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DBOD::Ldap::modify_attributes($conn, $nfs_datadir_address_base, 
        ['SC-NFS-VOLUME-LOCAL-PATH' => "/ORA/dbs03/" . $DBNAME,
         'SC-NFS-VOLUME-SERVER-PATH' => "/ORA/dbs03/" . $DBNAME,
         'SC-NFS-VOLUME-SERVER' => $serverdata,]);
    
    # Modify SC-ADDRESSES
    DEBUG 'Address customization';
    my $address_base = "SC-DB-ADDRESS-ID=0,SC-DB-ADDRESSES=db-addresses," .
        "SC-ENTITY=$entity,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DBOD::Ldap::modify_attributes($conn, $address_base, 
        ['SC-DB-ADDRESS-IP' => "${hostname}.cern.ch",
         'SC-DB-ADDRESS-PORT' => $port, ]);
    
    # If the instance is going to be in a CRS:
    if (defined $crs) {
        DEBUG 'CRS Customization';
        DBOD::Ldap::modify_attributes($conn, $address_base, 
            ['SC-DB-ADDRESS-IP' => "${ip_alias}"]);
        set_crs($conn, $new_entity);
        }
    else {
        # Single host (normal) case
        # Modify SC-HOSTS
        DEBUG 'Single instance customization';
        my $host_base = "SC-HOST-ID=1,SC-HOSTS=hosts,SC-ENTITY=$entity," .
            "SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
        DBOD::Ldap::modify_attributes($conn, $host_base, 
            ['SC-HOST-NAME' => "${hostname}" ,
             'SC-TNS-LISTENER-NAME' => $socket, ]);
        }

    DEBUG 'Timestamping LDAP entity';
    timestamp_entity($conn, $entity);

    # create TNS-net-services entry
    DEBUG 'Creating tnsnetservices LDAP entry';
    create_tnsnetservice($conn, $entity, uc $dbname);

    # Closes LDAP connection
    $conn->unbind();
    $conn->disconnect();

    return;
}

sub create_tnsnetservice {
    my ($conn, $entity_name, $dbname) = @_;
    my $tnsnames_address_base = "SC-TNS-NET-SERVICE-NAME=dbod_template_con," .
        "SC-CATEGORY=tnsnetservices,ou=syscontrol,dc=cern,dc=ch";
    DEBUG 'Fetches tnsnetservice template';
    my $template = DBOD::Ldap::get_entity($conn, $tnsnames_address_base);
    
    # Substitutes entity name in template
    my $tnsname = $entity_name . "_con";
    foreach my $entry (@{$template}) {
        my $dn = $entry->dn();
        $dn =~ s/dbod_template_con/$tnsname/g; 
        $entry->dn($dn);
        $entry->replace( 'SC-ENTITY-REF' => $entity_name );
        $entry->replace( 'SC-TNS-INSTANCE-NAME' => $dbname );
        $entry->replace( 'SC-TNS-NET-SERVICE-NAME' => $tnsname );
        DEBUG 'Adding LDAP entry: ' . $entry;
        my $mesg = $conn->add($entry); # Writes new entry
        $mesg->code && die $mesg->error; 
        }

    return;
}


#TODO : Evaluate this method
sub migrate_instance_template {
    my ($entity_name, $migrate_to, $conf_ref) = @_;
    
    my $conn = DBOD::Ldap::get_LDAP_conn($conf_ref);
    
    my $dbname = $migrate_to->{'dbname'};
    my $port = $migrate_to->{'port'};
    my $socket = $migrate_to->{'socket'};
    my $hostname = $migrate_to->{'host'};
    my $ip_alias = "${hostname}.cern.ch";
    my $serverdata = $migrate_to->{'serverdata'};
    my $serverlogs = $migrate_to->{'serverlogs'};
    
    # Adds NFS volumes
    my $nfsvols = DBOD::Ldap::load_LDIF('nfsvols');
    substitute_template_dns($nfsvols, $entity_name);
    foreach my $nfs_entry (@{$nfsvols}) {
         $nfs_entry->update($conn);
     }
    # binlog nfs vol server
    my $nfs_binlogs_address_base = "SC-NFS-VOLUME-ID=1,SC-NFS-VOLUMES=nfs-volumes," .
        "SC-ENTITY=$entity_name,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DBOD::Ldap::modify_attributes($conn, $nfs_binlogs_address_base, 
        ['SC-NFS-VOLUME-LOCAL-PATH' => "/ORA/dbs02/$dbname",
         'SC-NFS-VOLUME-SERVER-PATH' => "/ORA/dbs02/$dbname",
         'SC-NFS-VOLUME-SERVER' => "$serverlogs",]);
    
    # datadir nfs vol server
    my $nfs_datadir_address_base = "SC-NFS-VOLUME-ID=2,SC-NFS-VOLUMES=nfs-volumes,".
        "SC-ENTITY=$entity_name,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DBOD::Ldap::modify_attributes($conn, $nfs_datadir_address_base, 
        ['SC-NFS-VOLUME-LOCAL-PATH' => "/ORA/dbs03/$dbname",
         'SC-NFS-VOLUME-SERVER-PATH' => "/ORA/dbs03/$dbname",
         'SC-NFS-VOLUME-SERVER' => "$serverdata",]);
    
    # Modify SC-ADDRESSES
    my $address_base = "SC-DB-ADDRESS-ID=0,SC-DB-ADDRESSES=db-addresses," .
        "SC-ENTITY=$entity_name,SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DBOD::Ldap::modify_attributes($conn, $address_base, 
        ['SC-DB-ADDRESS-IP' => $ip_alias,
         'SC-DB-ADDRESS-PORT' => $port, ]);

    # Modify SC-HOSTS
    my $host_base = "SC-HOST-ID=1,SC-HOSTS=hosts,SC-ENTITY=$entity_name," .
        "SC-CATEGORY=entities,ou=syscontrol,dc=cern,dc=ch";
    DBOD::Ldap::modify_attributes($conn, $host_base, 
        ['SC-HOST-NAME' => $hostname ,
         'SC-TNS-LISTENER-NAME' => $socket, ]);

    # Timestamp entity in SC-COMMENT attribute
    timestamp_entity($conn, $entity_name);

    # Closes LDAP connection
    $conn->unbind();
    $conn->disconnect();

    return;
}


1;
