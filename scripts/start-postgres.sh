#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly CONTAINER_NAME="${POSTGRES_CONTAINER_NAME:-stacks_postgres}"
readonly POSTGRES_SERVICE="stacks-blockchain-postgres"
readonly DATA_ROOT="${POSTGRES_DATA_ROOT:-${REPO_ROOT}/postgresql}"
readonly HARDENED_PROFILE="${REPO_ROOT}/security/postgres-no-connect-seccomp.json"
readonly HARDEN_AUTH_SCRIPT="${SCRIPT_DIR}/harden-postgres-auth.sh"
readonly INIT_COMPLETE_LOG="PostgreSQL init process complete; ready for start up."
readonly TIMEOUT_SECONDS="${POSTGRES_START_TIMEOUT_SECONDS:-180}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/start-postgres.sh
  ./scripts/start-postgres.sh --initialize

The default command starts an existing PostgreSQL cluster with loopback SCRAM
authentication and the no-connect seccomp profile. Pass --initialize only for
a deliberately new, empty data directory.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

find_pgdata_if_present() {
  local -a version_files=()
  local version_file

  while IFS= read -r -d '' version_file; do
    version_files+=("${version_file}")
  done < <(find "${DATA_ROOT}" -mindepth 1 -maxdepth 4 -type f -name PG_VERSION -print0 2>/dev/null)

  (( ${#version_files[@]} <= 1 )) || \
    die "Expected at most one PG_VERSION below ${DATA_ROOT}; found ${#version_files[@]}."
  if (( ${#version_files[@]} == 1 )); then
    dirname -- "${version_files[0]}"
  fi
}

wait_for_host_postgres() {
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    if pg_isready -q -h 127.0.0.1 -p "${STACKS_PG_PORT}"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

application_psql() {
  PGPASSWORD="${STACKS_PG_PASSWORD}" psql \
    --no-password \
    --host 127.0.0.1 \
    --port "${STACKS_PG_PORT}" \
    --username stacks_blockchain_api \
    --dbname stacks_blockchain_api \
    --set ON_ERROR_STOP=1 "$@"
}

start_hardened() {
  local hardened_container_id seccomp_mode security_options

  echo "Starting PostgreSQL with loopback authentication and the hardened seccomp profile."
  POSTGRES_SECCOMP_PROFILE="${HARDENED_PROFILE}" \
    docker compose up -d --force-recreate --no-deps "${POSTGRES_SERVICE}"
  hardened_container_id="$(docker inspect -f '{{.Id}}' "${CONTAINER_NAME}")"

  if ! wait_for_host_postgres; then
    docker compose logs --tail=100 "${POSTGRES_SERVICE}" >&2 || true
    docker stop "${hardened_container_id}" >/dev/null 2>&1 || true
    die "PostgreSQL did not become ready within ${TIMEOUT_SECONDS} seconds."
  fi

  if ! application_psql --tuples-only --no-align --command 'SELECT 1' >/dev/null; then
    docker stop "${hardened_container_id}" >/dev/null 2>&1 || true
    die "PostgreSQL rejected STACKS_PG_PASSWORD for stacks_blockchain_api; the recreated container was stopped."
  fi

  if PGPASSWORD="invalid-password-for-auth-check" psql \
    --no-password \
    --host 127.0.0.1 \
    --port "${STACKS_PG_PORT}" \
    --username stacks_blockchain_api \
    --dbname stacks_blockchain_api \
    --command 'SELECT 1' >/dev/null 2>&1; then
    docker stop "${hardened_container_id}" >/dev/null 2>&1 || true
    die "PostgreSQL accepted an invalid loopback password; container stopped."
  fi

  seccomp_mode="$(docker exec "${CONTAINER_NAME}" awk '/^Seccomp:/ {print $2}' /proc/1/status)"
  security_options="$(docker inspect -f '{{json .HostConfig.SecurityOpt}}' "${CONTAINER_NAME}")"
  if [[ "${seccomp_mode}" != "2" ]] || [[ "${security_options}" != *seccomp=* ]]; then
    docker stop "${hardened_container_id}" >/dev/null 2>&1 || true
    die "PostgreSQL is not running with the configured seccomp profile; container stopped."
  fi

  if docker exec "${CONTAINER_NAME}" bash -c \
    "exec 3<>/dev/tcp/127.0.0.1/${STACKS_PG_PORT}" 2>/dev/null; then
    docker stop "${hardened_container_id}" >/dev/null 2>&1 || true
    die "The hardened PostgreSQL container can still initiate a connection; container stopped."
  fi

  echo "PostgreSQL is ready: loopback requires SCRAM and outbound connect() is blocked."
}

mode="start"
case "${1:-}" in
  "") ;;
  --initialize) mode="initialize" ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

command -v docker >/dev/null || die "docker is required."
command -v pg_isready >/dev/null || die "pg_isready is required on the host."
command -v psql >/dev/null || die "psql is required on the host."
docker compose version >/dev/null || die "the Docker Compose plugin is required."
: "${STACKS_PG_PORT:?STACKS_PG_PORT is required; run through 'direnv exec .'}"
: "${STACKS_PG_PASSWORD:?STACKS_PG_PASSWORD is required; run through 'direnv exec .'}"
[[ -f "${HARDENED_PROFILE}" ]] || die "Missing seccomp profile: ${HARDENED_PROFILE}"
[[ -x "${HARDEN_AUTH_SCRIPT}" ]] || die "Missing executable: ${HARDEN_AUTH_SCRIPT}"
[[ "${TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]] || die "POSTGRES_START_TIMEOUT_SECONDS must be a positive integer."

cd "${REPO_ROOT}"
docker compose config --quiet

readonly PGDATA_DIR="$(find_pgdata_if_present)"
if [[ -n "${PGDATA_DIR}" ]]; then
  if [[ "${mode}" == "initialize" ]]; then
    echo "PG_VERSION already exists; treating this as an existing database."
  fi
  "${HARDEN_AUTH_SCRIPT}"
  start_hardened
  exit 0
fi

if [[ "${mode}" != "initialize" ]]; then
  die "No initialized database below ${DATA_ROOT}. Re-run with --initialize only for a new database."
fi
if [[ -d "${DATA_ROOT}" ]] && [[ -n "$(find "${DATA_ROOT}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  die "${DATA_ROOT} is not empty but has no PG_VERSION; refusing to initialize it."
fi

echo "Initializing a new PostgreSQL cluster with Docker's built-in seccomp profile."
initializing=false
initializing_container_id=""
cleanup_unhardened_container() {
  local current_container_id=""
  current_container_id="$(docker inspect -f '{{.Id}}' "${CONTAINER_NAME}" 2>/dev/null || true)"
  if [[ "${initializing}" == "true" ]] \
    && [[ -n "${initializing_container_id}" ]] \
    && [[ "${current_container_id}" == "${initializing_container_id}" ]]; then
    echo "Stopping PostgreSQL because initialization or hardening did not complete." >&2
    docker stop "${initializing_container_id}" >/dev/null 2>&1 || true
  fi
}
trap cleanup_unhardened_container EXIT

POSTGRES_SECCOMP_PROFILE=builtin \
  docker compose up -d --force-recreate --no-deps "${POSTGRES_SERVICE}"
initializing_container_id="$(docker inspect -f '{{.Id}}' "${CONTAINER_NAME}")"
initializing=true

deadline=$((SECONDS + TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  running="$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || true)"
  [[ "${running}" == "true" ]] || {
    docker compose logs --tail=100 "${POSTGRES_SERVICE}" >&2 || true
    die "PostgreSQL exited during initialization."
  }
  logs="$(docker logs "${CONTAINER_NAME}" 2>&1)"
  [[ "${logs}" == *"${INIT_COMPLETE_LOG}"* ]] && break
  sleep 2
done

logs="$(docker logs "${CONTAINER_NAME}" 2>&1)"
if [[ "${logs}" != *"${INIT_COMPLETE_LOG}"* ]]; then
  docker compose logs --tail=100 "${POSTGRES_SERVICE}" >&2 || true
  die "PostgreSQL initialization did not complete within ${TIMEOUT_SECONDS} seconds."
fi

echo "Initialization completed; recreating PostgreSQL with the hardened profile."
"${HARDEN_AUTH_SCRIPT}"
docker compose stop "${POSTGRES_SERVICE}"
start_hardened
initializing=false
trap - EXIT
