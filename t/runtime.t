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
        my $exit_code = $rt->run_cmd('non-existing-command');
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


done_testing();
