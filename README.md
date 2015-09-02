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

* [DBOD::Api](https://github.com/cerndb/DBOD-core/blob/master/lib/DBOD/Api.pm): Internal class which fetches instance metadata from the [DB On Demand API](https://github.com/cerndb/dbod-api) server
    * **_api_client($config, $auth)**: Returns an authenticated client for the REST API
    * **_api_get_entity_metadata($entity, $config)**: Returns entity metadata from the API
    * **get_entity_metadata($entity)**: Fetches entity metadata either from the API server or from the cache
    * **load_cache($config)**: Loads cached metadata
* [DBOD::Config](https://github.com/cerndb/DBOD-core/blob/master/lib/DBOD/Config.pm) : Internal class to interact with the configuration file
    * **load** : Reads and parses configuration file, returning contents as a hash reference
* [DBOD::DB](https://github.com/cerndb/DBOD-core/blob/master/lib/DBOD/DB.pm): Internal class which interacts with the instance RDBMS
    * **do($statement, $bind_values)**: Executes an statement. Doesn't return anything 
    * **execute_sql_file($filename)**: Loads a file with SQL statements and executes them
    * **select($statement, $bind_values)**: Executes an statement and returns an array reference with the results.
* [DBOD::Job](https://github.com/cerndb/DBOD-core/blob/master/lib/DBOD/Job.pm): External class. Base class for commands
* [DBOD::Runtime](https://github.com/cerndb/DBOD-core/blob/master/lib/DBOD/Runtime.pm): A set of helper methods for different system related tasks
    * **run_cmd($cmd_str, $timeout)**: Executes an external command raising a timeout alarm after ```$timeout``` seconds, if this parameter is defined
    * **ssh** ($arg_ref): Executes commands over ssh
    * **scp_get**: Copy files/folders from a remote host  

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

=======

## Basic example: ping

```
pcitdb46:src (master*) $ perl ping               
Mandatory parameter 'entity' missing in call to "eval"

usage: ping [-?h] [long options...]
    --logger                 
    -h -? --usage --help    Prints this usage information.
    --entity STR             
    --md_cache KEY=STR...    
    --config KEY=STR...      
    --metadata KEY=STR...    
    --db                     

pcitdb46:src (master*) $ perl ping --entity pinocho
2015/06/15 17:41:46 Executing: select * from dod_dbmon.ping;
2015/06/15 17:41:46 Executing: delete from dod_dbmon.ping;
2015/06/15 17:41:46 Executing: insert into dod_dbmon.ping values (curdate(),curtime());
2015/06/15 17:41:46 [0]
```

## Extending the DBOD::Job class. 

```
pcitdb46:src (master*) $ perl mysql_recovery --entity pinocho
Mandatory parameter 'snapshot' missing in call to "eval"

usage: mysql_recovery [-?h] [long options...]
    --logger                 
    --snapshot STR           
    -h -? --usage --help    Prints this usage information.
    --entity STR             
    --md_cache KEY=STR...    
    --config KEY=STR...      
    --metadata KEY=STR...    
    --db                     
```
