#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd $DIR

echo 'Stopping stacks-node, timeout: 10mins'
docker-compose down -t 600 stacks-blockchain
docker-compose down stacks-blockchain-api
docker-compose down stacks-blockchain-postgres
