use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;

require_ok('DBOD::DB');

# MySQL Tests
subtest 'mysql' => sub {
    my $db = DBOD::DB->new(
        db_dsn => 'DBI:mysql:host=localhost',
        db_user => 'travis',
        db_password => '',
        db_attrs => { AutoCommit => 1, } 
    );
    ok($db->do('use test',), 'Select test database');
    ok($db->do('drop table if exists a'), 'Drop table');
    ok($db->do('create table a (a int, b varchar(32))',), 'Create table');
    my @values =  (1, 'test', 2, 'test2');
    ok($db->do('insert into a values (?, ?)', \@values), 'Insert values');
    my $result = $db->select('select * from a');
    note ref($result);
    note Dumper $result;
    isa_ok($result, 'ARRAY', 'Select result is Array');
};

done_testing();

__DATA__
use mysql;
select * from mysql.user;


