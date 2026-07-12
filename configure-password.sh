#!/bin/bash
docker exec -it stacks_postgres psql -Upostgres -p $STACKS_PG_PORT stacks_blockchain_api -c "ALTER USER stacks_blockchain_api WITH PASSWORD '$STACKS_PG_PASSWORD';"
