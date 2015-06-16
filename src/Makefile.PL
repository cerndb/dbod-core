use warnings;
use strict;
use inc::Module::Install;
use File::ShareDir;

author  'Ignacio Coterillo <ignacio.coterillo@cern.ch>';
version '0.5';
license 'GPLv3';

name    'DBOD';

requires    'Log::Log4perl' => 0;
requires    'YAML::Syck' => 0;
requires    'File::ShareDir' => 0;
requires    'Moose' => 0;
requires    'MooseX::Log::Log4perl' => 0;
requires    'MooseX::Getopt' => 0;
requires    'MooseX::Role::DBIx::Connector' => 0;
requires    'Config::General' => 0;
requires    'DBD::Oracle' => 0;
requires    'Switch' => 0;
requires    'REST::Client' => 0;

test_requires 'Test::More' => 0;

install_share;

WriteAll;
