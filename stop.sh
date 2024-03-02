#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd $DIR

echo 'Stopping stacks-node, timeout: 60mins'
docker stop -t 3600 stacks_node
docker stop stacks_api
docker stop stacks_postgres
docker compose down
