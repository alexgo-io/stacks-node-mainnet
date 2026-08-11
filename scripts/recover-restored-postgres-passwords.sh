#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly DATA_ROOT="${POSTGRES_DATA_ROOT:-${REPO_ROOT}/postgresql}"
readonly POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:18-trixie}"
readonly POSTGRES_CONTAINER_NAME="${POSTGRES_CONTAINER_NAME:-stacks_postgres}"
readonly RECOVERY_CONTAINER_NAME="${POSTGRES_RECOVERY_CONTAINER_NAME:-stacks_postgres_recovery}"
readonly HARDENED_PROFILE="${REPO_ROOT}/security/postgres-no-connect-seccomp.json"
readonly TIMEOUT_SECONDS="${POSTGRES_RECOVERY_TIMEOUT_SECONDS:-180}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

find_pgdata() {
  local -a version_files=()
  local version_file

  while IFS= read -r -d '' version_file; do
    version_files+=("${version_file}")
  done < <(find "${DATA_ROOT}" -mindepth 1 -maxdepth 4 -type f -name PG_VERSION -print0 2>/dev/null)

  (( ${#version_files[@]} == 1 )) || \
    die "Expected exactly one PG_VERSION below ${DATA_ROOT}; found ${#version_files[@]}."
  dirname -- "${version_files[0]}"
}

command -v docker >/dev/null || die "docker is required."
command -v pg_isready >/dev/null || die "pg_isready is required on the host."
command -v psql >/dev/null || die "psql is required on the host."
: "${STACKS_PG_PORT:?STACKS_PG_PORT is required; run through 'direnv exec .'}"
: "${STACKS_PG_PASSWORD:?STACKS_PG_PASSWORD is required; run through 'direnv exec .'}"
[[ "${STACKS_PG_PORT}" =~ ^[1-9][0-9]*$ ]] || die "STACKS_PG_PORT must be a positive integer."
[[ "${TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]] || die "POSTGRES_RECOVERY_TIMEOUT_SECONDS must be a positive integer."
[[ -f "${HARDENED_PROFILE}" ]] || die "Missing seccomp profile: ${HARDENED_PROFILE}"

readonly PGDATA_DIR="$(find_pgdata)"
[[ ! -e "${PGDATA_DIR}/postmaster.pid" ]] || \
  die "${PGDATA_DIR}/postmaster.pid exists; PostgreSQL may still be running or was not stopped cleanly."

normal_running="$(docker inspect -f '{{.State.Running}}' "${POSTGRES_CONTAINER_NAME}" 2>/dev/null || true)"
[[ "${normal_running}" != "true" ]] || \
  die "${POSTGRES_CONTAINER_NAME} is running; stop the normal PostgreSQL service before recovery."
if docker inspect "${RECOVERY_CONTAINER_NAME}" >/dev/null 2>&1; then
  die "A container named ${RECOVERY_CONTAINER_NAME} already exists; inspect and remove it before retrying."
fi

readonly PGDATA_UID="$(stat -c '%u' "${PGDATA_DIR}")"
readonly CALLER_GID="$(id -g)"
[[ "${PGDATA_UID}" =~ ^[0-9]+$ ]] || die "Could not determine the PostgreSQL data owner UID."
[[ "${CALLER_GID}" =~ ^[0-9]+$ ]] || die "Could not determine the caller GID."

recovery_dir="$(mktemp -d /tmp/stacks-pg-recovery.XXXXXX)"
readonly RECOVERY_DIR="${recovery_dir}"
readonly RECOVERY_HBA="${RECOVERY_DIR}/pg_hba.conf"
recovery_started=false

cleanup() {
  if [[ "${recovery_started}" == "true" ]]; then
    if docker inspect "${RECOVERY_CONTAINER_NAME}" >/dev/null 2>&1; then
      if ! docker stop --time 30 "${RECOVERY_CONTAINER_NAME}" >/dev/null 2>&1; then
        echo "Could not stop ${RECOVERY_CONTAINER_NAME}; preserving ${RECOVERY_DIR}." >&2
        return 1
      fi
    fi
    recovery_started=false
  fi
  case "${RECOVERY_DIR}" in
    /tmp/stacks-pg-recovery.*) rm -rf -- "${RECOVERY_DIR}" ;;
    *) echo "Refusing to remove unexpected temporary path: ${RECOVERY_DIR}" >&2 ;;
  esac
}
trap cleanup EXIT

printf '%s\n' 'local all all trust' >"${RECOVERY_HBA}"
chown "${PGDATA_UID}:${CALLER_GID}" "${RECOVERY_DIR}" "${RECOVERY_HBA}"
chmod 0770 "${RECOVERY_DIR}"
chmod 0640 "${RECOVERY_HBA}"

echo "Starting isolated PostgreSQL recovery (no network and a temporary Unix socket only)."
docker run --detach --rm \
  --name "${RECOVERY_CONTAINER_NAME}" \
  --network none \
  --security-opt "seccomp=${HARDENED_PROFILE}" \
  --user "${PGDATA_UID}:${CALLER_GID}" \
  --volume "${PGDATA_DIR}:/pgdata" \
  --volume "${RECOVERY_DIR}:/recovery" \
  --entrypoint postgres \
  "${POSTGRES_IMAGE}" \
  -D /pgdata \
  -c 'listen_addresses=' \
  -c 'unix_socket_directories=/recovery' \
  -c 'unix_socket_permissions=0770' \
  -c 'hba_file=/recovery/pg_hba.conf' \
  -c 'password_encryption=scram-sha-256' \
  -p "${STACKS_PG_PORT}" >/dev/null
recovery_started=true

deadline=$((SECONDS + TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  running="$(docker inspect -f '{{.State.Running}}' "${RECOVERY_CONTAINER_NAME}" 2>/dev/null || true)"
  if [[ "${running}" != "true" ]]; then
    docker logs "${RECOVERY_CONTAINER_NAME}" >&2 2>/dev/null || true
    die "The isolated PostgreSQL recovery container exited before becoming ready."
  fi
  if pg_isready -q --host "${RECOVERY_DIR}" --port "${STACKS_PG_PORT}"; then
    break
  fi
  sleep 2
done
pg_isready -q --host "${RECOVERY_DIR}" --port "${STACKS_PG_PORT}" || \
  die "The isolated PostgreSQL recovery server did not become ready within ${TIMEOUT_SECONDS} seconds."

psql \
  --no-password \
  --host "${RECOVERY_DIR}" \
  --port "${STACKS_PG_PORT}" \
  --username postgres \
  --dbname postgres \
  --set ON_ERROR_STOP=1 <<'SQL'
\getenv role_password STACKS_PG_PASSWORD
ALTER ROLE stacks_blockchain_api LOGIN PASSWORD :'role_password';
ALTER ROLE postgres PASSWORD NULL;
SQL

verification="$(psql \
  --no-password \
  --host "${RECOVERY_DIR}" \
  --port "${STACKS_PG_PORT}" \
  --username postgres \
  --dbname postgres \
  --tuples-only \
  --no-align \
  --set ON_ERROR_STOP=1 \
  --command "SELECT p.rolpassword IS NULL, a.rolcanlogin AND a.rolpassword LIKE 'SCRAM-SHA-256$%' FROM pg_authid AS p CROSS JOIN pg_authid AS a WHERE p.rolname = 'postgres' AND a.rolname = 'stacks_blockchain_api'")"
[[ "${verification}" == "t|t" ]] || \
  die "Role verification failed; expected a passwordless postgres role and a SCRAM application role."

cleanup
trap - EXIT
echo "Cold-backup PostgreSQL credentials recovered: the application role uses STACKS_PG_PASSWORD and postgres remains passwordless."
