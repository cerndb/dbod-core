use strict;
use warnings;

use Test::More;
use File::ShareDir;
use File::Temp qw/ tempfile /;
use Data::Dumper;
use Net::LDAP::LDIF;
use Log::Log4perl;



use_ok('DBOD::Templates');
use DBOD::Templates;

use JSON;

use DBOD::Config;

my $share_dir = DBOD::Config::get_share_dir();
my %config = ();
$config{'common'} = { template_folder => "${share_dir}/templates" };

subtest "load_template" => sub {

    my $template;
    my %input = ();

    is(DBOD::Templates::load_template('wrong', 
            'type', \%input, \%config, \$template), 0, 'Non existent template');

};

subtest "create_metadata" => sub {

    my %input = ();
    $input{subcategory} = 'MYSQL';
    my $template = DBOD::Templates::create_metadata(\%input, \%config);
    ok(decode_json $template, 'mysql metadata template is valid JSON');
   
    $input{subcategory} = 'PG';
    $template = DBOD::Templates::create_metadata(\%input, \%config);
    ok(decode_json $template, 'pg metadata template is valid JSON');
   
};


subtest "create_ldap_entry" => sub {
    
    my %input = ();
    $input{subcategory} = 'mysql';
    my $entries = DBOD::Templates::create_ldap_entry(\%input, \%config);
    ok(scalar @{$entries} == 11, 'MYSQL ldap_entry: Array of entries');
    print ">>>>>>> " . scalar @{$entries};
    
    $input{subcategory} = 'pg';
    $entries = DBOD::Templates::create_ldap_entry(\%input, \%config);
    ok(scalar @{$entries} == 11, 'PG ldap_entry: Array of entries');
    
};

done_testing();
