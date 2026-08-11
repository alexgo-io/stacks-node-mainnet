#!/usr/bin/env bash
set -Eeuo pipefail

# The official image runs this only while initializing a new cluster. Read the
# password from the environment inside psql so it never appears in SQL files or
# the process command line.
psql --set ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "${POSTGRES_DB}" <<'SQL'
\getenv role_password POSTGRES_PASSWORD
ALTER ROLE stacks_blockchain_api PASSWORD :'role_password';
ALTER ROLE postgres PASSWORD NULL;
SQL
