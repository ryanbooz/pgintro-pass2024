##be sure you create the bluebox database first
##connect to the server
docker exec -it PGIntro "bash";


## done within bash
pg_dump backmeup > /bu/backmeup.dmp

## don't run
pg_dumpall > /bu

##switch back to DBeaver

pg_basebackup -D /bu/basebu24



##restores
## from basic dump
psql -d backmeup -f /bu/backmeup.dmp

## get bluebox online
pg_restore -C -d postgres -U postgres /bu/bluebox_v0.3.dump 





