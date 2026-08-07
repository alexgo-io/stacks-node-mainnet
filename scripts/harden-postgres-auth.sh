#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly DATA_ROOT="${POSTGRES_DATA_ROOT:-${REPO_ROOT}/postgresql}"
readonly POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:18-trixie}"

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
readonly PGDATA_DIR="$(find_pgdata)"
readonly HBA_FILE="${PGDATA_DIR}/pg_hba.conf"
[[ -f "${HBA_FILE}" ]] || die "Missing ${HBA_FILE}."

# Edit through the PostgreSQL image so this also works when the host user cannot
# write files owned by the container's postgres UID. The replacement is atomic;
# database files and the Docker volume are never removed or recreated.
docker run --rm \
  --user 0:0 \
  --volume "${PGDATA_DIR}:/pgdata" \
  --entrypoint bash \
  "${POSTGRES_IMAGE}" -ceu '
    hba=/pgdata/pg_hba.conf
    tmp="${hba}.harden.$$"
    trap '\''rm -f "${tmp}"'\'' EXIT

    sed -E '\''/^[[:space:]]*(#|$)/! s/([[:space:]])trust([[:space:]]*(#.*)?)$/\1scram-sha-256\2/'\'' \
      "${hba}" >"${tmp}"

    if awk '\''
      /^[[:space:]]*(#|$)/ { next }
      {
        for (i = 1; i <= NF; i++) {
          if ($i == "trust") found = 1
        }
      }
      END { exit(found ? 0 : 1) }
    '\'' "${tmp}"; then
      echo "Refusing to install pg_hba.conf: an active trust rule remains." >&2
      exit 1
    fi

    chown --reference="${hba}" "${tmp}"
    chmod --reference="${hba}" "${tmp}"

    if cmp -s "${hba}" "${tmp}"; then
      echo "PostgreSQL HBA already requires authentication; no change needed."
      exit 0
    fi

    mv "${tmp}" "${hba}"
    trap - EXIT
    echo "Replaced active trust rules in pg_hba.conf with scram-sha-256."
  '
