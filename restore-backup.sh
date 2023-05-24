#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd $DIR

if [ -e postresql ] || [ -e stacks-node ]; then
  echo "The stacks postgres/node is already running, this is for fresh start"
  echo "If you need to reset and restore again, please stop postgres and remove ./postresql and ./stacks-node"
  exit 0
fi

curl https://stacks-archive.alexlab.co/postgresql.tar.gz | tar -xzv
curl https://stacks-archive.alexlab.co/stacks-node.tar.gz | tar -xzv
docker-compose up -d
