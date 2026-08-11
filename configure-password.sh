#!/usr/bin/env bash
set -Eeuo pipefail

: "${STACKS_PG_PORT:?STACKS_PG_PORT is required}"
: "${STACKS_PG_PASSWORD:?STACKS_PG_PASSWORD is required}"

# The application role can rotate its own password. Set
# STACKS_PG_CURRENT_PASSWORD when it differs from the new STACKS_PG_PASSWORD.
# Cold backups whose stored password is unknown must use
# start-from-cold-backup.sh instead.
PGPASSWORD="${STACKS_PG_CURRENT_PASSWORD:-${STACKS_PG_PASSWORD}}" psql \
  --no-password \
  --host 127.0.0.1 \
  --port "${STACKS_PG_PORT}" \
  --username stacks_blockchain_api \
  --dbname stacks_blockchain_api \
  --set ON_ERROR_STOP=1 <<'SQL'
\getenv role_password STACKS_PG_PASSWORD
ALTER ROLE CURRENT_USER PASSWORD :'role_password';
SQL
