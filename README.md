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
supported by the service (e.g: *dbod_recovery*, *dbod_backup*, *dbod_shutdown*,...).

The objective of the module is to have a compact code base including all the 
shared functionality between the different types of instances supported in the service. 
This module consolidates functionality currently found in six different libraries while 
also trying set a base which eases the implementation of future extensions.

## Basic Requirements and Assumptions

* Perl library requirements can be seen in [Makefile.PL](https://github.com/cerndb/DBOD-core/blob/master/Makefile.PL).
* A configuration file is required. A valid template is [available](https://github.com/cerndb/DBOD-core/blob/master/share/dbod-core.conf-template)
    * In the CERN environment the configuration file is populated and managed using Puppet.

## Development setup installation

This procedure assumes you have installed *cpanm*, and requires the use of *inc::Module::Install*.

```bash
   $ git clone https://github.com/cerndb/DBOD-core.git dbod-core
   $ cd dbod-core
   $ cpanm inc::Module::Install
   $ cpanm --installdeps .
```

Please note that the list of requirements include database drivers, which in turn require
additional packages to be build. The names of the required extra packages will vary depend on
your environment, but will be related to header files and libraries. For example, in the
case of the MySQL driver you will need *libmysqlclient-dev* if you are using Debian 8.4,
and *MySQL-shared* or *mysql-libs* in some other RPM based distributions.

Additional dependencies may be required for additional database drivers

