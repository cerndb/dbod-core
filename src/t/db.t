package DBOD;

use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;
use Data::Handle;

require_ok('DBOD::DB');

use DBOD::DB;

BEGIN { Log::Log4perl->easy_init() };

# MySQL Tests
subtest 'mysql' => sub {

    # Create object 
    my $db = DBOD::DB->new(
        db_dsn => 'DBI:mysql:host=localhost',
        db_user => 'travis',
        db_password => '',
        db_attrs => { AutoCommit => 1, } 
    );
    ok($db->do('use test',), 'Select test database');
    ok(!$db->do('use;',), 'Wrong command');
    ok($db->do('drop table if exists a'), 'Drop table');
    ok($db->do('create table a (a int, b varchar(32))',), 'Create table');
    my @values =  (1, 'test', 2, 'test2');
    ok($db->do('insert into a values (?, ?)', \@values), 'Insert values');
    my $result = $db->select('select * from a');
    note ref($result);
    note Dumper $result;
    isa_ok($result, 'ARRAY', 'Select result is Array');
    ok(!$db->select('select * from b'), 'Wrong select');
    
    # Read from file and execute
    ok(!$db->execute_sql_file('/tmp/wrongtest'), "Execute non-existant file");
    
    my $handle = Data::Handle->new(__PACKAGE__);
    my $fh;
    open $fh, '>', '/tmp/test.sql' or fail('Cannot write to test.sql');
    my @lines = $handle->getlines();
    note Dumper \@lines;
    open $fh, '>', '/tmp/test2.sql' or fail('Cannot write to test2.sql');
    foreach (@lines) {
            print $fh $_;
        }
    close $fh;
    $result = $db->execute_sql_file('/tmp/test.sql');
    note Dumper $result;
    is($result, undef);
    
    # Causing error
    @lines = grep {!/drop/} @lines;
    note Dumper \@lines;
    open $fh, '>', '/tmp/test2.sql' or fail('Cannot write to test2.sql');
    foreach (@lines) {
            print $fh $_;
        }
    close $fh;
    $result = $db->execute_sql_file('/tmp/test2.sql');
    note Dumper $result;
    is($result, undef);

};

done_testing();

__DATA__
use test;
drop table if exists a;
create table a (a int, b varchar(32));
insert into a values (3, 'test3');
