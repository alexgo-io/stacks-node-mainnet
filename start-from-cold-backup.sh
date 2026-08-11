#!/usr/bin/env bash
set -Eeuo pipefail

readonly DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${DIR}"

./scripts/recover-restored-postgres-passwords.sh
./start.sh
