#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Log::Log4perl qw(:easy);
use Data::Dumper;

use_ok('DBOD::CRS');

BEGIN { Log::Log4perl->easy_init() };

use Test::MockObject;
use Test::MockModule;

use DBOD::Runtime;
my $runtime = Test::MockModule->new('DBOD::Runtime');

subtest 'get_resource_state' => sub {

        my $output;
        my $target_state = 'UNKNOWN';

        # Error getting CRS resource state
        $runtime->mock( 'run_str' =>
            sub {
                $$output = $target_state;
                return 0;
            });
        my $state = DBOD::CRS::get_resource_state('TEST', 'CRS02');
        is ($state, undef, 'get_resource_state: ERROR');

        # Normal behaviour
        $runtime->mock( 'run_str' =>
            sub {
                $$output = $target_state;
                return 0;
            });
        my $state = DBOD::CRS::get_resource_state('TEST', 'CRS02');
        is ($state, undef, 'get_resource_state: ERROR');
    };

subtest 'start_resource' => sub {

        my $output;
        my $target_state = 'UNKNOWN';

        # Mocking get_resource_state
        my $crs = Test::MockModule->new('DBOD::CRS');
        $crs->mock('get_resource_state'=> sub {return 'UNKNOWN';});

        # Normal behaviour
        $runtime->mock( 'run_str' =>
            sub {
                $$output = $target_state;
                return 0;
            });

        my $state = DBOD::CRS::start_resource('TEST', 'CRS02');
        is ($state, 0, 'start_resource: ERROR, UNKNOWN resource state');

        $crs->mock('get_resource_state'=> sub {return 'INTERMEDIATE';});
        $state = DBOD::CRS::start_resource('TEST', 'CRS02');
        is ($state, 0, 'start_resource: ERROR, INTERMEDIATE resource state');

        $crs->mock('get_resource_state'=> sub {return 'ONLINE';});
        $state = DBOD::CRS::start_resource('TEST', 'CRS02');
        is ($state, 1, 'start_resource: Nothing to do, ONLINE resource state');

        $crs->mock('get_resource_state'=> sub {return 'OFFLINE';});
        $state = DBOD::CRS::start_resource('TEST', 'CRS02');
        is ($state, 0, 'start_resource: ONLINE resource state, FAILED start');

        $runtime->mock( 'run_str' =>
            sub {
                $$output = $target_state;
                return 1;
            });

        $crs->mock('get_resource_state'=> sub {return 'OFFLINE';});
        $state = DBOD::CRS::start_resource('TEST', 'CRS02');
        is ($state, 1, 'start_resource: ONLINE resource state, SUCCESSFUL start');

        $crs->mock('get_resource_state'=> sub {return undef;});
        $state = DBOD::CRS::start_resource('TEST', 'CRS02');
        is ($state, 0, 'start_resource: ERROR, Resource not found');

        $crs->mock('get_resource_state'=> sub {return 'not an state';});
        $state = DBOD::CRS::start_resource('TEST', 'CRS02');
        is ($state, 0, 'start_resource: ERROR, Resource not found');
    };

subtest 'stop_resource' => sub {

        my $output;
        my $target_state = 'UNKNOWN';

        # Mocking get_resource_state
        my $crs = Test::MockModule->new('DBOD::CRS');
        $crs->mock('get_resource_state'=> sub {return 'UNKNOWN';});

        # Normal behaviour
        $runtime->mock( 'run_str' =>
            sub {
                $$output = $target_state;
                return 0;
            });

        my $state = DBOD::CRS::stop_resource('TEST', 'CRS02');
        is ($state, 0, 'stop_resource: ERROR, UNKNOWN resource state');

        $crs->mock('get_resource_state'=> sub {return 'INTERMEDIATE';});
        $state = DBOD::CRS::stop_resource('TEST', 'CRS02');
        is ($state, 0, 'stop_resource: ERROR, INTERMEDIATE resource state');

        $crs->mock('get_resource_state'=> sub {return 'OFFLINE';});
        $state = DBOD::CRS::stop_resource('TEST', 'CRS02');
        is ($state, 1, 'stop_resource: Nothing to do, OFFLINE resource state');

        $crs->mock('get_resource_state'=> sub {return 'ONLINE';});
        $state = DBOD::CRS::stop_resource('TEST', 'CRS02');
        is ($state, 0, 'stop_resource: ONLINE resource state, FAILED stop');

        $runtime->mock( 'run_str' =>
            sub {
                $$output = $target_state;
                return 1;
            });

        $crs->mock('get_resource_state'=> sub {return 'ONLINE';});
        $state = DBOD::CRS::stop_resource('TEST', 'CRS02');
        is ($state, 1, 'stop_resource: ONLINE resource state, SUCCESSFUL stop');

        $crs->mock('get_resource_state'=> sub {return undef;});
        $state = DBOD::CRS::stop_resource('TEST', 'CRS02');
        is ($state, 0, 'stop_resource: ERROR, Resource not found');

        $crs->mock('get_resource_state'=> sub {return 'not an state';});
        $state = DBOD::CRS::stop_resource('TEST', 'CRS02');
        is ($state, 0, 'stop_resource: ERROR, Resource not found');
    };



done_testing();

