#!/usr/bin/env bash
set -Eeuo pipefail

readonly DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${DIR}"

./scripts/start-postgres.sh
docker compose up -d envoy stacks-blockchain-api stacks-blockchain
