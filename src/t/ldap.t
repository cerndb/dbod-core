use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

use_ok('DBOD::Ldap');

use Test::MockObject;
use Test::MockModule;
use Test::MockObject::Extends;

my $share_dir = File::ShareDir::dist_dir('DBOD');
my %config = ();
$config{'common'} = { template_folder => "${share_dir}/templates" };
my %ldap = (
    port => '636',
    url => 'ldap_uri.server.domain',
    scheme => '',
    protocol => 'ldaps',
    userdn => 'userdn',
    scope => 'subtree',
);
$config{ldap} = \%ldap;

subtest "load_ldif" => sub {

    my $template;
    my %input = ();

    # Succesfull LDIF file loads are tested as a by-product of the
    # part of the templates test suite.

    # Try to read a wrongly formated LDIF file 
    is(DBOD::Ldap::load_ldif("${share_dir}/test.json"),undef, 'Incorrect LDIF load');

};

# Mock a LDAP connection object
my $ldap_client = Test::MockObject->new();
my $msg = Test::MockObject->new();
$msg->set_false('code');
$msg->mock('error', sub { return ''} );
$msg->mock('entries', sub { return [Net::LDAP::Entry->new(), Net::LDAP::Entry->new()]} );

$ldap_client->mock('bind', sub {return $msg});
$ldap_client->mock('unbind', sub {return $msg});
$ldap_client->mock('disconnect', sub {return $msg});
$ldap_client->mock('add', sub {return $msg});
$ldap_client->mock('modify', sub {return $msg});
$ldap_client->mock('search', sub {return $msg});

my @attributes = [ 'SC-PACKAGES-GROUP' => 'DBOD_RHEL6',
    'SC-PACKAGES-GROUP' => 'DBOD_SLC6OS',];

# This is publicly accesible ldap server
my $ldap_server = 'pksldap.tttc.de';

my $ldap_m = Test::MockModule->new('Net::LDAP');
$ldap_m->mock('new', sub {return $ldap_client} );

subtest "get_connection" => sub {

    my $conn = DBOD::Ldap::get_connection(\%config);
    like($conn, qr/Test::MockObject/, 'get_connection returns object');
   
    $msg->set_true('code');
    $conn = DBOD::Ldap::get_connection(\%config);
    like($conn, qr/Test::MockObject/, 'get_connection binding FAILS');
    
};

subtest "timestamp_entity" => sub {

    my %input = ( dbname => 'test', );
    is(DBOD::Ldap::timestamp_entity($ldap_client, \%input), undef, 'timestamp_entity OK');
    
};

subtest "get_entity" => sub {

    $msg->set_true('code');
    $msg->mock('error', sub { return 'LDAP OK'} );
    my $entity = DBOD::Ldap::get_entity($ldap_client, 'entity_base', undef);
    like ($entity, qr/ARRAY/, 'get_entity OK');
    
    $msg->set_false('code');
    $msg->mock('error', sub { return 'LDAP ERROR'} );
    $msg->mock('entries', sub { return undef } );
    $entity = DBOD::Ldap::get_entity($ldap_client, 'entity_base', 'subtree');
    like ($entity, qr/ARRAY/, 'get_entity FAIL');

};


subtest "add_attributes" => sub {

    $msg->set_true('code');
    $msg->mock('error', sub { return 'LDAP OK'} );
    ok(DBOD::Ldap::add_attributes($ldap_client, @attributes), 'add_attributes OK');
    
    $msg->set_false('code');
    $msg->mock('error', sub { return 'LDAP ERROR'} );
    is(DBOD::Ldap::add_attributes($ldap_client, @attributes), undef, 'add_attributes FAIL');

};

subtest "modify_attributes" => sub {

    $msg->set_true('code');
    $msg->mock('error', sub { return 'LDAP OK'} );
    ok(DBOD::Ldap::modify_attributes($ldap_client, @attributes), 'modify_attributes OK');
    
    $msg->set_false('code');
    $msg->mock('error', sub { return 'LDAP ERROR'} );
    is(DBOD::Ldap::modify_attributes($ldap_client, @attributes),undef, 'modify_attributes FAIL');

};

subtest "create_entity" => sub {

    use DBOD::Templates;
    
    my %input = ( dbname => 'test', );
    $config{'common'} = { template_folder => "${share_dir}/templates" };
    $input{subcategory} = 'mysql';

    ok(DBOD::Ldap::create_instance(\%input, \%config), 'create_instance');
    
};

done_testing();
