
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
