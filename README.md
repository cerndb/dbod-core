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

## Requirements and assumptions



## Structure

## Configuration

## Examples




