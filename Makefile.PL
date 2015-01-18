use warnings;
use strict;
use inc::Module::Install;

author      'Ignacio Coterillo <ignacio.coterillo@cern.ch>';
version    '0.1';
license     'GPLv3';

name          'DBOD-core';
requires      'Log::Log4perl' => 0;
requires      'YAML::Syck' => 0;
requires      'File::ShareDir' => 0;

WriteAll;
