# DBOD-core

[![Build Status](https://travis-ci.org/cerndb/DBOD-core.svg?branch=master)](https://travis-ci.org/cerndb/DBOD-core)
[![Coverage Status](https://coveralls.io/repos/cerndb/DBOD-core/badge.svg)](https://coveralls.io/r/cerndb/DBOD-core)

## Objectives

Because of how the [CERN DB On Demand](http://information-technology.web.cern.ch/services/database-on-demand)
service evolved historically (far outgrowing its original design specifications) 
the current implementation of some of its components is open to improvements for 
better accomodating to new changes or extensions in the service architecture.

At the lowest level of the service managing infrastructure you can find a set of 
commands which execute certain actions for each kind of database server 
supported by the service (e.g: *mysql_recovery*, *postgresql_backup*, *oracle_shutdown*,...).

The objective of the module is to have a compact code base including all the 
shared functionality between the different types of instances supported in the service. 
This module consolidates functionality currently found in six different libraries while 
also trying set a base which eases the implementation of future extensions.

## Components

* **DBOD::Api**: Internal class which fetches instance metadata from the [DB On Demand API](https://github.com/cerndb/dbod-api) server
* **DBOD::Config** : Internal class to interact with the configuration file
* **DBOD::DB**: Internal class which interacts with the instance RDBMS
* **DBOD::Job**: External class. The base of any command
* **DBOD::Runtime**: A set of methods helping perform system tasks (run external commands, perform operations over SSH, etc.)

## How to use?

Look at the following example implementing a ping command that connects to the 
instance RDBMS and performs a transaction as a way of checking the status of 
the database:

```perl
#!/usr/bin/env perl
# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

use strict;
use warnings;

use DBOD::Job;

# Initiates logger
BEGIN { 
    Log::Log4perl->easy_init() ;
}
my $job = DBOD::Job->new_with_options();

sub body {
    my $params = shift;
    my $type = lc $job->metadata->{'subcategory'};
    $job->db->execute_sql_file($job->config->{$type}->{'helper_ping'});
    $job->_output(0);
}

$job->run(\&body);
```
* The ping command creates an instance of the DBOD::Job class, which requires a mandatory paramter **entity**. In case this parameter is not supplied an error will be raised.
* The configuration file is processed internally and exposed in the ```$job->config``` hash reference
* Instance metadata is fetched from the API and exposed in the ```$job->metadata``` hash reference
* The DBOD::Job instance internal DB connector is initialized with the entity metadata
* The following sentence: ```$job->db->execute_sql_file($job->config->{$type}->{'helper_ping'});``` loads a SQL file defined in the configuration for each database *$type* and executes its contents

## Requirements and assumptions

* Perl library requirements can be seen in [Makefile.PL](https://github.com/cerndb/DBOD-core/blob/master/Makefile.PL).
* A configuration file is required. A valid template is [available](https://github.com/cerndb/DBOD-core/blob/master/share/dbod-core.conf-template)
    * In the CERN environment the configuration file is populated and managed using Puppet.




