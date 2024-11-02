docker exec -it PGIntro "bash";

cd ~/pgdata/data

vi postgresql.conf
## edit shared_preload_libraries to include pg_stat_statements

## i to insert, esc to quit inserting
## :wq to save & quit
## yes, I use nano more than vi, but I'm not installing it