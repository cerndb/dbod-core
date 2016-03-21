#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;

require_ok( 'DBOD::Storage::NetApp::ZAPI' );

use DBOD::Storage::NetApp::ZAPI;

BEGIN { Log::Log4perl->easy_init() };

use Test::MockObject;
use Test::MockModule;

# ZAPI Mocking objects
my $na_server= Test::MockObject->new();
my $na_element = Test::MockObject->new();
$na_element->set_isa('NaElement');

$na_server->mock(set_style => sub {return $na_element;});
$na_server->mock(set_port => sub {return $na_element;});
$na_server->mock(set_transport_type => sub {return $na_element;});
$na_server->mock(set_vserver => sub {return $na_element;});
$na_server->mock(set_admin_user => sub {return $na_element;});
$na_server->mock(invoke => sub {return $na_element;});


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
        $na_element->mock( results_errno => sub {return 0;});
        my $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver',
            'version');
        ok($res, 'create_server_ok');
        $na_element->mock( results_errno => sub {return 0;});
        $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver');
        ok($res, 'create_server default version');
        $na_element->mock( results_errno => sub {return 1;});
        $na_element->mock( results_reason => sub {return "Wrong username";});
        $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver');
        ok(!$res, 'create_server username error');

    };

subtest 'is_Cmode_mount' => sub {
        is($zapi->is_Cmode_mount('/vol/test'), 0, '7 mode mount');
        is($zapi->is_Cmode_mount('/ORA/test'), 1, 'C mode mount');
    };

subtest 'get_mount_point_NAS_regex' => sub {
        my $pairs = $zapi->get_mount_point_NAS_regex('ORA');
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
        $na_element->mock( results_errno => sub {return 0;});
        ok($zapi->snap_delete($na_server, 'Volume', 'delete'), 'snap_delete OK');
        $na_element->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_delete($na_server, 'Volume', 'delete'), 'snap_delete FAIL');
    };

subtest 'snap_create' => sub {
        $na_element->mock( results_errno => sub {return 0;});
        ok($zapi->snap_create($na_server, 'Volume', 'create'), 'snap_create OK');
        $na_element->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_create($na_server, 'Volume', 'create'), 'snap_create FAIL');
    };

subtest 'snap_restore' => sub {
        $na_element->mock( results_errno => sub {return 0;});
        ok($zapi->snap_restore($na_server, 'Volume', 'restore'), 'snap_restore OK');
        $na_element->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_restore($na_server, 'Volume', 'restore'), 'snap_restore FAIL');
    };

subtest 'snap_prepare_snap_list' => sub {
        # This calls exercise also the snap_list method
        $na_server->mock(invoke => sub {return $na_element;});
        $na_element->mock( results_errno => sub {return 0;});
        my $snaplist = Test::MockObject->new();
        my $snapshot = Test::MockObject->new();
        $na_element->mock( child_get => sub {return $snaplist;});
        $snaplist->mock(children_get => sub {return ($snapshot);});
        $snapshot->mock(child_get_int => sub {return 1;});
        $snapshot->mock(child_get_string => sub {return "TEST";});
        ok($zapi->snap_prepare($na_server, 'Volume', 2), 'snap_prepare OK');
        $na_element->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_delete($na_server, 'Volume', 'delete'), 'snap_prepare FAIL');
    };

subtest 'snap_clone' => sub {
        $na_server->mock(invoke_elem => sub {return $na_element;});
        $na_element->mock( 'child_add_string' );
        ok(!$zapi->snap_clone($na_server, 'Volume', 'snapshot', 'junction'), 'snap_clone OK');
        $na_element->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_clone($na_server, 'Volume', 'snapshot', 'junction'), 'snap_clone FAIL');
    };

subtest 'create_server_from_mount_point' => sub {
        $na_element->mock( results_errno => sub {return 0;});
        ok($zapi->create_server_from_mount_point('localhost', 'mount_point'),
            'create_server_from_mount_point OK');
    };



done_testing();
