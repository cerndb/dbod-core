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
my $na_server_object= Test::MockObject->new();
my $na_element_object = Test::MockObject->new();
$na_element_object->set_isa('NaElement');

$na_server_object->mock(set_style => sub {return $na_element_object;});
$na_server_object->mock(set_port => sub {return $na_element_object;});
$na_server_object->mock(set_transport_type => sub {return $na_element_object;});
$na_server_object->mock(set_vserver => sub {return $na_element_object;});
$na_server_object->mock(set_admin_user => sub {return $na_element_object;});
$na_server_object->mock(invoke => sub {return $na_element_object;});


my $na_server = Test::MockModule->new('NaServer');
$na_server->mock( new => $na_server_object );

my $na_element = Test::MockModule->new('NaElement');
$na_element->mock( new => $na_element_object );

# Tests configuration
my %config = ();
my %api = ();
$api{'timeout'} = "3";
$api{'user'} = "API-USER";
$api{'password'} = "XXXXXXXXX";
$api{'entity_metadata_endpoint'} = "api/v1/entity";
$api{'entity_ipalias_endpoint'} = "api/v1/entity/alias";
$config{'api'} = \%api;

# Tests

my $zapi = DBOD::Storage::NetApp::ZAPI->new();

subtest 'create_server' => sub {
        $na_element_object->mock( results_errno => sub {return 0;});
        my $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver',
            'version');
        ok($res, 'create_server_ok');
        $na_element_object->mock( results_errno => sub {return 0;});
        $res = $zapi->create_server(
            'ipaddr',
            'username',
            'password',
            'vserver');
        ok($res, 'create_server default version');
        $na_element_object->mock( results_errno => sub {return 1;});
        $na_element_object->mock( results_reason => sub {return "Wrong username";});
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
        $na_element_object->mock( results_errno => sub {return 0;});
        is($zapi->check_API_call($na_element_object), undef, 'Correct API call');
        $na_element_object->mock( results_errno => sub {return 1;});
        $na_element_object->mock( results_reason => sub {return "API call test";});
        is($zapi->check_API_call($na_element_object), 1, 'Error in API call');
    };

subtest 'snap_delete' => sub {
        $na_element_object->mock( results_errno => sub {return 0;});
        ok($zapi->snap_delete($na_server_object, 'Volume', 'delete'), 'snap_delete OK');
        $na_element_object->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_delete($na_server_object, 'Volume', 'delete'), 'snap_delete FAIL');
    };

subtest 'snap_create' => sub {
        $na_element_object->mock( results_errno => sub {return 0;});
        ok($zapi->snap_create($na_server_object, 'Volume', 'create'), 'snap_create OK');
        $na_element_object->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_create($na_server_object, 'Volume', 'create'), 'snap_create FAIL');
    };

subtest 'snap_restore' => sub {
        $na_element_object->mock( results_errno => sub {return 0;});
        ok($zapi->snap_restore($na_server_object, 'Volume', 'restore'), 'snap_restore OK');
        $na_element_object->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_restore($na_server_object, 'Volume', 'restore'), 'snap_restore FAIL');
    };

subtest 'snap_prepare_snap_list' => sub {
        # This calls exercise also the snap_list method
        $na_element_object->mock( results_errno => sub {return 0;});
        ok($zapi->snap_prepare($na_server_object, 'Volume', 2), 'snap_prepare OK');
        $na_element_object->mock( results_errno => sub {return 1;});
        ok(!$zapi->snap_delete($na_server_object, 'Volume', 'delete'), 'snap_prepare FAIL');
    };

done_testing();

