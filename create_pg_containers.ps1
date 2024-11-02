##create core PostgreSQL image w/ volume
docker pull postgres;

docker run `
    --name PGFirst `
    -e POSTGRES_PASSWORD=*cthulhu1988 `
    -v C:\bu:/bu `
    -d postgres;


## timescale
docker pull timescale/timescaledb-ha:pg16;

docker run `
    --name PGIntro `
    -p 5432:5432 `
    -e POSTGRES_PASSWORD=*cthulhu1988 `
    -v C:\bu:/bu `
    -d timescale/timescaledb-ha:pg16;       

## what is the status
docker ps -a



##cleanup - after presentation!
docker stop PGFirst;
docker rm PGFirst;
docker stop PGIntro;
docker rm PGIntro;
