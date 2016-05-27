#!/usr/bin/perl
use strict;
use warnings;
use DBOD::Config;
use Test::More;
use Data::Dumper;

require_ok( 'DBOD::Storage::NetApp::ZAPI' );

use DBOD::Storage::NetApp::ZAPI;
use File::ShareDir;

use DBOD;

BEGIN { Log::Log4perl->easy_init() };

use Test::MockObject;
use Test::MockModule;

# ZAPI Mocking objects
my $na_server= Test::MockObject->new();
my $na_element = Test::MockObject->new();
$na_element->set_isa('NaElement');

my $na_element_ok = Test::MockObject->new();
$na_element_ok->set_isa('NaElement');
$na_element_ok->mock( results_errno => sub {return 0;});
my $na_element_fail = Test::MockObject->new();
$na_element_fail->set_isa('NaElement');
$na_element_fail->mock( results_errno => sub {return 1;});

my $na_server_mod = Test::MockModule->new('NaServer');
$na_server_mod->mock( new => $na_server );

my $na_element_mod = Test::MockModule->new('NaElement');
$na_element_mod->mock( new => $na_element );

# Tests configuration
my %config = ();
my %filers = ();
$filers{'user'} = "API-USER";
$filers{'password'} = "XXXXXXXXX";
$config{filers} = \%filers;

# Tests

my $zapi = DBOD::Storage::NetApp::ZAPI->new( config => \%config );

subtest 'create_server' => sub {
        $na_server->mock(new => sub {return $na_element_ok;});
        $na_server->mock(set_style => sub {return $na_element_ok;});
        $na_server->mock(set_port => sub {return $na_element_ok;});
        $na_server->mock(set_admin_user => sub {return $na_element_ok;});
        $na_server->mock(set_transport_type => sub {return $na_element_ok;});
        $na_server->mock(set_vserver => sub {return $na_element_ok;});
        my $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver',
            'version');
        ok($res, 'create_server style ok');

        $na_server->mock(set_style => sub {return $na_element_fail;});
        $na_element_fail->mock( results_reason => sub {return "Unable to set login style";});
        $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver',
            'version');
        ok(!$res, 'create_server style fail');

        $na_server->mock(set_style => sub {return $na_element_ok;});
        $na_server->mock(set_admin_user => sub {return $na_element_fail;});
        $na_element_fail->mock( results_reason => sub {return "Wrong username";});
        $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver');
        ok(!$res, 'create_server username error');

        $na_server->mock(set_admin_user => sub {return $na_element_ok;});
        $na_server->mock(set_transport_type => sub {return $na_element_fail;});
        $na_element_fail->mock( results_reason => sub {return "Wrong transport";});
        $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver');
        ok(!$res, 'create_server transport error');

        $na_server->mock(set_transport_type => sub {return $na_element_ok;});
        $na_server->mock(set_vserver => sub {return $na_element_fail;});
        $na_element_fail->mock( results_reason => sub {return "Error creating vserver";});
        $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver');
        ok(!$res, 'create_server transport error');
    };

subtest 'get_mount_point_NAS_regex' => sub {
        my $mtab_file = DBOD::Config::get_share_dir() . '/sample_mtab';
        my $mntpoint = '/ORA/dbs03/PINOCHO';
        my $regex = "^(.*?dbnas[\\w-]+):(.*?)\\s+($mntpoint)\\s+nfs";
        my $pairs = $zapi->get_mount_point_NAS_regex($regex, undef, $mtab_file);
        isa_ok($pairs, 'HASH');
        my @exclusion_list = (undef);
        $pairs = $zapi->get_mount_point_NAS_regex($regex, \@exclusion_list, $mtab_file);
        isa_ok($pairs, 'HASH');
    };

subtest 'check_API_call' => sub {
        $na_element->mock( results_errno => sub {return 0;});
        is($zapi->check_API_call($na_element), undef, 'Correct API call');
        $na_element->mock( results_errno => sub {return 1;});
        $na_element->mock( results_reason => sub {return "API call test";});
        is($zapi->check_API_call($na_element), 1, 'Error in API call');
    };

subtest 'snap_delete' => sub {
        $na_server->mock(invoke => sub {return $na_element_ok;});
        is($zapi->snap_delete($na_server, 'Volume', 'delete'), $OK, 'snap_delete OK');
        $na_server->mock(invoke => sub {return $na_element_fail;});
        $na_element_fail->mock( results_reason => sub {return "snap_delete FAIL";});
        is($zapi->snap_delete($na_server, 'Volume', 'delete'), $ERROR, 'snap_delete FAIL');
    };

subtest 'snap_create' => sub {
        $na_server->mock(invoke => sub {return $na_element_ok;});
        is($zapi->snap_create($na_server, 'Volume', 'create'), $OK, 'snap_create OK');
        $na_server->mock(invoke => sub {return $na_element_fail;});
        $na_element_fail->mock( results_reason => sub {return "snap_create FAIL";});
        is($zapi->snap_create($na_server, 'Volume', 'create'), $ERROR, 'snap_create FAIL');
    };

subtest 'snap_restore' => sub {
        $na_server->mock(invoke => sub {return $na_element_ok;});
        is($zapi->snap_restore($na_server, 'Volume', 'restore'), $OK, 'snap_restore OK');
        $na_server->mock(invoke => sub {return $na_element_fail;});
        $na_element_fail->mock( results_reason => sub {return "snap_restore FAIL";});
        is($zapi->snap_restore($na_server, 'Volume', 'restore'), $ERROR, 'snap_restore FAIL');
    };

subtest 'snap_prepare_snap_list' => sub {
        # This calls exercise also the snap_list method
        $na_server->mock(invoke => sub {return $na_element;});
        $na_element->mock( results_errno => sub {return 0;});
        my $snaplist = Test::MockObject->new();
        my $snapshot = Test::MockObject->new();
        $na_element->mock( child_get => sub {return $snaplist;});
        $snaplist->mock(children_get => sub {return ($snapshot, $snapshot, $snapshot);});
        $snapshot->mock(child_get_int => sub {return 1;});
        $snapshot->mock(child_get_string => sub {return "TEST";});
        is($zapi->snap_prepare($na_server, 'Volume', 1), $OK, 'snap_prepare OK. Multiple snapshots');
        $snaplist->mock(children_get => sub {return ($snapshot);});
        is($zapi->snap_prepare($na_server, 'Volume', 1), $OK, 'snap_prepare OK. Single snapshot');
        $na_server->mock(invoke => sub {return $na_element_fail;});
        $na_element_fail->mock( results_reason => sub {return "snapshot-list-info FAIL";});
        is($zapi->snap_prepare($na_server, 'Volume', 1), $ERROR, 'snap_prepare FAIL');
        $na_server->mock(invoke => sub {return $na_element_ok;});
        $snaplist->mock(children_get => sub {return 0;});
        $snaplist->mock(child_get => sub {return 0;});
        is($zapi->snap_prepare($na_server, 'Volume', 1), $ERROR, 'snap_prepare FAIL. No Snapshots');
    };

subtest 'snap_clone' => sub {
        $na_server->mock(invoke_elem => sub {return $na_element;});
        $na_element->mock( 'child_add_string' );
        ok($zapi->snap_clone($na_server, 'Volume', 'snapshot', 'junction'), 'snap_clone OK');
        $na_element->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_clone($na_server, 'Volume', 'snapshot', 'junction'), 'snap_clone FAIL');
    };

subtest 'create_server_from_mount_point' => sub {
        $na_element->mock( results_errno => sub {return 0;});
        ok($zapi->create_server_from_mount_point('localhost', 'mount_point'),
            'create_server_from_mount_point OK');
    };

subtest 'get_server_and_volname' => sub {
        my $mtab_file = DBOD::Config::get_share_dir() . '/sample_mtab';
        my $mntpoint = '/ORA/dbs03/PINOCHO';
        # Underlying get_volinfo call requirements
        $na_element->mock( child_add => sub {return;});
        $na_element->mock( sprintf => sub {return "sprintf string";});
        $na_element->mock( children_get => sub {return $na_element;});
        $na_element->mock( child_get_string => sub {return "child_string";});
        $na_element->mock( children_get => sub {return $na_element;});
        $na_element->mock( child_get => sub {return ($na_element, $na_element, $na_element);});
        # Tests
        ok($zapi->get_server_and_volname($mntpoint, $mtab_file),
            'get_server_and_volname OK');
        $na_element->mock( results_errno => sub {return 1;});
        isa_ok($zapi->get_server_and_volname('nothing_to_find', $mtab_file),
            'ARRAY',
            'get_server_and_volname FAIL. No NAS mounts');
    };

subtest 'get_volinfo' => sub {
        $na_server->mock(new => sub {return $na_element;});
        $na_element->mock( results_errno => sub {return 0;});
        $na_element->mock( children_get => sub {return $na_element;});
        $na_element->mock( child_get_string => sub {return "child_string";});
        $na_element->mock( sprintf => sub {return "sprintf string";});
        $na_element->mock( child_add => sub {return;});
        $na_element->mock( child_get => sub {return ($na_element, $na_element, $na_element);});
        ok($zapi->get_volinfo($na_server, 'mount_point'),
            'get_volinfo OK');
        $na_element->mock( new => sub {return;});

    };

done_testing();
