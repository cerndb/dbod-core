#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Log::Log4perl qw(:easy);
use Data::Dumper;

use_ok('DBOD::Systems::CRS');

BEGIN { Log::Log4perl->easy_init() };

use Test::MockObject;
use Test::MockModule;

use DBOD;
use DBOD::Runtime;
my $runtime = Test::MockModule->new('DBOD::Runtime');

subtest 'get_resource_state' => sub {

        my $target_state = 'UNKNOWN';

        # Normal behaviour
        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = $target_state;
                return $OK;
            });

        my $state = DBOD::Systems::CRS::get_resource_state('TEST', 'CRS02');
        is ($state, $target_state, 'get_resource_state: OK');

        # Error getting CRS resource state
        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = '';
                return $ERROR;
            });
        $state = DBOD::Systems::CRS::get_resource_state('TEST', 'CRS02');
        is ($state, undef, 'get_resource_state: ERROR');

    };

subtest 'start_resource' => sub {

        my $target_state = 'UNKNOWN';

        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = $target_state;
                return $OK;
            });

        # Mocking get_resource_state
        my $crs = Test::MockModule->new('DBOD::Systems::CRS');
        $crs->mock('get_resource_state'=> sub {return 'UNKNOWN';});

        my $state = DBOD::Systems::CRS::start_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'start_resource: ERROR, UNKNOWN resource state');

        $crs->mock('get_resource_state'=> sub {return 'INTERMEDIATE';});
        $state = DBOD::Systems::CRS::start_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'start_resource: ERROR, INTERMEDIATE resource state');

        $crs->mock('get_resource_state'=> sub {return 'ONLINE';});
        $state = DBOD::Systems::CRS::start_resource('TEST', 'CRS02');
        is ($state, $OK, 'start_resource: Nothing to do, ONLINE resource state');

        $crs->mock('get_resource_state'=> sub {return 'OFFLINE';});
        $state = DBOD::Systems::CRS::start_resource('TEST', 'CRS02');
        is ($state, $OK, 'start_resource: ONLINE resource state, SUCCESSFUL start');

        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = $target_state;
                return $ERROR;
            });

        $crs->mock('get_resource_state'=> sub {return 'OFFLINE';});
        $state = DBOD::Systems::CRS::start_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'start_resource: ONLINE resource state, FAILED start');

        $crs->mock('get_resource_state'=> sub {return undef;});
        $state = DBOD::Systems::CRS::start_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'start_resource: ERROR, Resource not found');

        $crs->mock('get_resource_state'=> sub {return 'not an state';});
        $state = DBOD::Systems::CRS::start_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'start_resource: ERROR, Resource not found');
    };

subtest 'stop_resource' => sub {

        # Mocking get_resource_state
        my $crs = Test::MockModule->new('DBOD::Systems::CRS');
        $crs->mock('get_resource_state'=> sub {return 'UNKNOWN';});

        my $target_state = 'UNKNOWN';
        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = $target_state;
                return $OK;
            });

        my $state = DBOD::Systems::CRS::stop_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'stop_resource: ERROR, UNKNOWN resource state');

        $crs->mock('get_resource_state'=> sub {return 'INTERMEDIATE';});
        $state = DBOD::Systems::CRS::stop_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'stop_resource: ERROR, INTERMEDIATE resource state');

        $crs->mock('get_resource_state'=> sub {return 'ONLINE';});
        $state = DBOD::Systems::CRS::stop_resource('TEST', 'CRS02');
        is ($state, $OK, 'stop_resource: ONLINE resource state, SUCCESSFUL stop');

        $runtime->mock( 'run_cmd' =>
            sub {
                my %args = @_;
                my $output_ref = $args{output};
                $$output_ref = $target_state;
                return $ERROR;
            });

        $crs->mock('get_resource_state'=> sub {return 'ONLINE';});
        $state = DBOD::Systems::CRS::stop_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'stop_resource: ONLINE resource state, FAILED stop');

        $crs->mock('get_resource_state'=> sub {return 'OFFLINE';});
        $state = DBOD::Systems::CRS::stop_resource('TEST', 'CRS02');
        is ($state, $OK, 'stop_resource: Nothing to do, OFFLINE resource state');

        $crs->mock('get_resource_state'=> sub {return undef;});
        $state = DBOD::Systems::CRS::stop_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'stop_resource: ERROR, Resource not found');

        $crs->mock('get_resource_state'=> sub {return 'not an state';});
        $state = DBOD::Systems::CRS::stop_resource('TEST', 'CRS02');
        is ($state, $ERROR, 'stop_resource: ERROR, Resource not found');

    };



done_testing();

