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
        my $output;
        my $exit_code = $rt->run_cmd(cmd => 'hostname', output => \$output);
        is($exit_code, 0, 'Executing hostname');
        undef $output; my $output;
        $exit_code = $rt->run_cmd(cmd => 'non-existing-command', output => \$output);
        is($exit_code, undef, 'Missing executable');
        undef $output; my $output;
        $exit_code = $rt->run_cmd(cmd => 'ping localhost', timeout => 1, output => $output);
        is($exit_code, undef, 'Timeout command');
        undef $output; my $output;
        $exit_code = $rt->run_cmd(cmd => 'ls kk', output => \$output);
        is($exit_code, 512, 'ls non existing file');
    };

subtest 'run_str' => sub {
        my $rt = DBOD::Runtime->new();
        my $output;
        my $exit_code = $rt->run_str('hostname', \$output, undef, undef);
        is($exit_code, 1, 'Executing command');
        $exit_code = $rt->run_str('ls /usr/sbin/kk', \$output, undef, undef);
        is($exit_code, 0, 'Executing erroring command');
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

subtest 'get_instance_version' => sub {
        my $version = '5.6.17';
        my $target = '5617';
        my $rt = DBOD::Runtime->new();
        is($rt->get_instance_version($version), $target, 'Version format coversion validation');
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
