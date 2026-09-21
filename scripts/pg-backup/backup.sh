#!/usr/bin/env bash
set -euo pipefail

# ---- Configuration (override via environment, e.g. by sourcing backup.env) ----
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
# PGPASSWORD should be set in the environment, or use a .pgpass file instead.

BACKUP_ROOT="${BACKUP_ROOT:-/mnt/truenas-backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

DATE="$(date +%F)"
DEST="${BACKUP_ROOT}/${DATE}"
LOG_FILE="${DEST}/backup.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

fail() {
  local msg="$1"
  log "ERROR: $msg"
  exit 1
}

trap 'fail "Unexpected error on line $LINENO"' ERR

mkdir -p "$DEST"
log "Starting backup run -> ${DEST}"

# Sanity check the backup destination is actually mounted (not just an
# empty local dir left behind by a failed/unmounted NFS mount).
if ! mountpoint -q "$BACKUP_ROOT" 2>/dev/null; then
  log "WARNING: ${BACKUP_ROOT} does not appear to be a mount point. Continuing anyway, but verify your NFS mount if this is unexpected."
fi

export PGPASSWORD="${PGPASSWORD:-}"

# ---- Dump global objects (roles, tablespaces) ----
log "Dumping globals..."
pg_dumpall -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" --globals-only > "${DEST}/globals.sql" \
  || fail "pg_dumpall --globals-only failed"

# ---- Dump each non-template, connectable database ----
# Connect to the "postgres" maintenance database to run this query -- psql
# otherwise defaults to a database named after PGUSER, which may not exist.
DATABASES=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -tAc \
  "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true;") \
  || fail "Failed to list databases"

if [[ -z "$DATABASES" ]]; then
  fail "No databases found to back up"
fi

for db in $DATABASES; do
  log "Dumping database: ${db}"
  pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -Fc "$db" -f "${DEST}/${db}.dump" \
    || fail "pg_dump failed for database '${db}'"
done

# ---- Verify we actually produced non-empty files ----
for f in "${DEST}"/*.dump "${DEST}/globals.sql"; do
  [[ -s "$f" ]] || fail "Output file ${f} is missing or empty"
done

TOTAL_SIZE=$(du -sh "$DEST" | cut -f1)
log "Backup complete. ${DEST} (${TOTAL_SIZE})"

# ---- Prune old backups (dated subdirectories only) ----
log "Pruning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_ROOT" -maxdepth 1 -type d -regextype posix-extended \
  -regex '.*/[0-9]{4}-[0-9]{2}-[0-9]{2}' -mtime +"$RETENTION_DAYS" \
  -print -exec rm -rf {} \; | tee -a "$LOG_FILE"

log "Done."
