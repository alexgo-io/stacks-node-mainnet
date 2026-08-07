#!/usr/bin/env bash
set -Eeuo pipefail

: "${STACKS_PG_PORT:?STACKS_PG_PORT is required}"
: "${STACKS_PG_PASSWORD:?STACKS_PG_PASSWORD is required}"

# Administrative clients cannot run inside the hardened PostgreSQL container,
# because the no-connect seccomp profile blocks TCP and Unix-socket connect().
PGPASSWORD="${STACKS_PG_PASSWORD}" psql \
  --no-password \
  --host 127.0.0.1 \
  --port "${STACKS_PG_PORT}" \
  --username postgres \
  --dbname stacks_blockchain_api \
  --set ON_ERROR_STOP=1 <<'SQL'
\getenv role_password STACKS_PG_PASSWORD
ALTER ROLE stacks_blockchain_api PASSWORD :'role_password';
SQL
