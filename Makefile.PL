use warnings;
use strict;

use inc::Module::Install;

# Package metadata
author  'Ignacio Coterillo <ignacio.coterillo@cern.ch>';
version '0.76';
license 'GPLv3';
name    'DBOD';

configure_requires    'File::ShareDir' => 0;
configure_requires    'inc::Module::Install' => 0;

requires    'Log::Log4perl' => 0;
requires    'Log::Dispatch::FileRotate' => 0;
requires    'Log::Dispatch::Syslog' => 0;
requires    'YAML::Syck' => 0;
requires    'File::ShareDir' => 0;
requires    'Moose' => 0;
requires    'MooseX::AbstractFactory' => 0;
requires    'MooseX::Log::Log4perl' => 0;
requires    'MooseX::Role::DBIx::Connector' => 0;
requires    'MooseX::Getopt::Usage' => 0;
requires    'Config::General' => 0;
requires    'DBD::mysql' => 0;
requires    'DBD::Pg' => 0;
requires    'REST::Client' => 0;
requires    'Template' => 0;
requires    'IPC::Run' => 0;
requires    'Net::OpenSSH' => 0;
requires    'Net::LDAP' => 0;
requires    'JSON' => 0;
requires    'Try::Tiny' => 0;
requires    'Readonly' => 0;
requires    'SOAP::Lite' => 0;
requires    'autodie' => 0;

test_requires 'Test::More' => 0;
test_requires 'Test::MockModule' => 0;
test_requires 'Test::MockObject' => 0;
test_requires 'Test::MockObject::Extends' => 0;
test_requires 'Data::Handle' => 0;
test_requires 'Test::Output' => 0;

# Install share/ files
use File::ShareDir;
install_share;

# Install executables
install_script 'scripts/dbod-backup';
install_script 'scripts/dbod-init';
install_script 'scripts/dbod-ping';
install_script 'scripts/dbod-start';
install_script 'scripts/dbod-stop';
install_script 'scripts/dbod-upgrade';

WriteAll;
