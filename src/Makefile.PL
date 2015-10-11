use warnings;
use strict;
use inc::Module::Install;
use File::ShareDir;

author  'Ignacio Coterillo <ignacio.coterillo@cern.ch>';
version '0.5';
license 'GPLv3';

name    'DBOD';

requires    'Log::Log4perl' => 0;
requires    'Log::Dispatch::FileRotate' => 0;
requires    'Log::Dispatch::Syslog' => 0;
requires    'YAML::Syck' => 0;
requires    'File::ShareDir' => 0;
requires    'Moose' => 0;
requires    'MooseX::Log::Log4perl' => 0;
requires    'MooseX::Getopt' => 0;
requires    'MooseX::Role::DBIx::Connector' => 0;
requires    'Config::General' => 0;
requires    'DBI' => 0;
requires    'REST::Client' => 0;
requires    'Template' => 0;
requires    'IPC::Run' => 0;
requires    'Net::OpenSSH' => 0;
requires    'Net::LDAP' => 0;
requires    'JSON' => 0;
requires    'MooseX::Getopt::Usage' => 0;
requires    'Try::Tiny' => 0;
requires    'XML::Parser' => 0;

test_requires 'Test::More' => 0;

install_share;

WriteAll;
