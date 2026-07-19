#!/bin/sh
# PocketBase container entrypoint.
# Runs on every start: validates config, conditionally bootstraps the superuser,
# then execs the server. POSIX sh (busybox ash on Alpine).
set -e

DATA_DIR="/pb/pb_data"
DB_FILE="${DATA_DIR}/data.db"
PB_PORT="${PB_PORT:-8070}"

# ---- assemble global flags shared by every pocketbase invocation ----
set -- --dir="${DATA_DIR}"

if [ -n "${PB_ENCRYPTION_KEY}" ]; then
  # PocketBase requires the settings-encryption key to be exactly 32 chars.
  if [ "${#PB_ENCRYPTION_KEY}" -ne 32 ]; then
    echo "[entrypoint] ERROR: PB_ENCRYPTION_KEY must be exactly 32 characters (got ${#PB_ENCRYPTION_KEY})." >&2
    exit 1
  fi
  echo "[entrypoint] Settings encryption enabled."
  set -- "$@" --encryptionEnv=PB_ENCRYPTION_KEY
fi

GLOBAL_FLAGS="$*"

# ---- does the requested superuser already exist? ----
superuser_exists() {
  # No DB yet => first boot => cannot exist.
  [ -f "${DB_FILE}" ] || return 1
  count=$(sqlite3 "${DB_FILE}" \
    "SELECT COUNT(*) FROM _superusers WHERE email = '${PB_ADMIN_EMAIL}';" 2>/dev/null) || return 1
  [ "${count:-0}" -gt 0 ]
}

# ---- superuser bootstrap (always evaluated, before the server starts) ----
if [ -n "${PB_ADMIN_EMAIL}" ]; then
  if superuser_exists; then
    echo "[entrypoint] Superuser '${PB_ADMIN_EMAIL}' already exists — skipping creation."
  else
    if [ -z "${PB_ADMIN_PASSWORD}" ]; then
      echo "[entrypoint] ERROR: superuser '${PB_ADMIN_EMAIL}' does not exist and PB_ADMIN_PASSWORD is not set." >&2
      exit 1
    fi
    echo "[entrypoint] Creating superuser '${PB_ADMIN_EMAIL}'..."
    # shellcheck disable=SC2086
    /pb/pocketbase superuser create "${PB_ADMIN_EMAIL}" "${PB_ADMIN_PASSWORD}" ${GLOBAL_FLAGS}
  fi
else
  echo "[entrypoint] PB_ADMIN_EMAIL not set — skipping superuser bootstrap."
fi

echo "[entrypoint] Starting PocketBase on 0.0.0.0:${PB_PORT}"
# shellcheck disable=SC2086
exec /pb/pocketbase serve --http="0.0.0.0:${PB_PORT}" ${GLOBAL_FLAGS}
