#!/usr/bin/env bash
set -Eeuo pipefail

readonly DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${DIR}"

: "${STACKS_PG_PORT:?STACKS_PG_PORT is required}"
: "${STACKS_PG_PASSWORD:?STACKS_PG_PASSWORD is required}"

if [ -e postgresql ]; then
  echo "The stacks postgres is already running, this is for fresh start"
  echo "If you need to reset and restore again, please stop postgres and remove ./postgresql"
  exit 0
fi

mkdir postgresql
curl --fail --location --output postgresql/latest.dump \
  https://archive.hiro.so/mainnet/stacks-blockchain-api-pg/stacks-blockchain-api-pg-17-latest.dump

./scripts/start-postgres.sh --initialize

# The database container cannot initiate a connection under the no-connect
# profile. Restore through a short-lived client container on the host network.
docker run --rm \
  --network host \
  --env PGPASSWORD="${STACKS_PG_PASSWORD}" \
  --volume "${DIR}/postgresql/latest.dump:/backup/latest.dump:ro" \
  postgres:18-trixie \
  pg_restore \
    --host 127.0.0.1 \
    --port "${STACKS_PG_PORT}" \
    --username stacks_blockchain_api \
    --jobs 16 \
    --verbose \
    --create \
    --dbname stacks_blockchain_api \
    /backup/latest.dump
