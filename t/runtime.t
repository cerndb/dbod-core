use strict;
use warnings;

use Test::More;
use File::ShareDir;
use Data::Dumper;
use Log::Log4perl qw(:easy);

BEGIN { Log::Log4perl->easy_init() };

use_ok('DBOD::Runtime');


subtest 'run_cmd' => sub {
        my $rt = DBOD::Runtime->new();
        my $exit_code = $rt->run_cmd('hostname');
        is($exit_code, 0, 'Executing hostname');
        $exit_code = $rt->run_cmd('non-existing-command');
        is($exit_code, undef, 'Missing executable');
        $exit_code = $rt->run_cmd('ping localhost', 1);
        is($exit_code, undef, 'Timeout command');
        $exit_code = $rt->run_cmd('ls kk');
        is($exit_code, 512, 'ls non existing file');
    };

subtest 'result_code' => sub {
        my $rt = DBOD::Runtime->new();
        my $log = "Test log\n[0]";
        my $result_code = $rt->result_code($log);
        is($result_code, 0, 'Success result code');
        $log = "Test log\n[2]";
        $result_code = $rt->result_code($log);
        is($result_code, 2, 'Failure result code');
        $log = "Test log";
        $result_code = $rt->result_code($log);
        is($result_code, 1, 'Input missing result code');
    };

subtest 'my_wait' => sub {
        sub dummy {
            my @params = @_;
            return scalar @params;
        };
        my $rt = DBOD::Runtime->new();
        my @params = (1, 2, 3);
        my $result_code = $rt->mywait(\&dummy, @params);
        is($result_code, 3, 'mywait')
    };

subtest 'file_ops' => sub {

        # First we create a temporal file
        my $rt = DBOD::Runtime->new();
        my $tempfile = $rt->get_temp_filename('TEST_XXXX', '/tmp', '_test');

        # Write to File
        my @contents = ("Line1\n", "Line2\n");
        $rt->write_file_arr($tempfile, \@contents);

        # Read from file
        my @text = $rt->read_file($tempfile);
        ok(@text == @contents, 'Sucessfull Create-Write-Read Cycle');

        # Exercise error paths
        is($rt->read_file('/tmp/non-existing-file'), undef, 'Non existing file read');
        is($rt->write_file_arr('/sbin/kk', \@contents), undef, 'Non existing file write');
        is($rt->get_temp_filename(undef,undef,undef), undef, 'get_temp_file missing parameters');

    };

done_testing();
