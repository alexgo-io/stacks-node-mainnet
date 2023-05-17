#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd $DIR

if [ -e postresql ]; then
  echo "The stacks postgres is already running, this is for fresh start"
  echo "If you need to reset and restore again, please stop postgres and remove ./postresql"
  exit 0
fi

mkdir postgresql
curl -o postgresql/latest.dump https://archive.hiro.so/mainnet/stacks-blockchain-api-pg/stacks-blockchain-api-pg-15-7.1.10-latest.dump

docker-compose up -d stacks-blockchain-postgres
docker exec -it stacks_postgres pg_restore -j 8 -Upostgres -v -C -d alexgo /var/lib/postgresql/latest.dump
