## can be run locally, if installed
psql -?

## get into the container
docker exec -it PGIntro "bash";

## 
psql -?

## exit bash first
## running a query
psql -d postgres -U postgres -c 'SELECT attname FROM pg_stats'

## connect
psql -d postgres -U postgres
\l
\du


