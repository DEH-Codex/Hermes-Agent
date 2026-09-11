#!/bin/bash
# backup_state_db_to_qnap.sh
# Nightly rsync of Hermes state.db (185 MB, session history + FTS index) to QNAP NAS.
#
# Primary path: rsync-over-SSH using ed25519 key auth (no password, no keychain).
# Fallback path: SMB share via mount_smbfs → Finder AppleScript (needs keychain).
#
# Schedule via launchd (preferred) or cron. See ~/Library/LaunchAgents/com.hermes.qnap-backup.plist
#
# Prereqs (SSH path — primary):
#   1. QNAP user Scotthaus has milo's public key installed (QTS → Privilege → Users → Edit → SSH Public Key)
#   2. sqlite3 is in PATH (ships with macOS)
#   3. rsync is in PATH (ships with macOS)
#   4. SSH host key for 192.168.1.5 is in ~/.ssh/known_hosts (first connection prompts)
#
# Prereqs (SMB fallback — only if SSH key auth fails):
#   1. SMB share HermesBackups exists on QNAP
#   2. macOS keychain has Scotthaus's SMB password for 192.168.1.5
#      (security add-internet-password -a Scotthaus -s 192.168.1.5 -r "smb " -w)
#
# Why sqlite3 .backup instead of plain cp/rsync of the live DB:
#   state.db is in WAL mode (verify with `sqlite3 state.db 'PRAGMA journal_mode'`).
#   Copying a live WAL-mode DB can capture a half-written page, which silently
#   corrupts the FTS5 trigram index. sqlite3 .backup takes an online snapshot
#   via the DB's own backup API — atomic at the page level.

set -euo pipefail

QNAP_HOST="192.168.1.5"
QNAP_USER="Scotthaus"
# NAS-side destination path (via SSH). QNAP user homes live under /share/homes,
# but shared folders are under /share/<SHARE_NAME>. HermesBackups maps to /share/HermesBackups.
QNAP_REMOTE_DIR="/share/HermesBackups/hermes-backups/state-db"
SOURCE_DB="$HOME/.hermes/state.db"
SNAPSHOT_DIR="$HOME/.cache/hermes-backup-snapshots"
SNAPSHOT_FILE="$SNAPSHOT_DIR/state-$(date +%Y%m%d-%H%M%S).db"
LOG_DIR="$HOME/.hermes/logs"
LOG_FILE="$LOG_DIR/qnap-backup.log"
RETENTION_DAYS=14

log() {
    mkdir -p "$LOG_DIR"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG_FILE"
}

mkdir -p "$SNAPSHOT_DIR"

# 1. Take a consistent SQLite snapshot (online backup API)
log "Snapshotting $SOURCE_DB -> $SNAPSHOT_FILE"
sqlite3 "$SOURCE_DB" ".backup '$SNAPSHOT_FILE'"

# Verify snapshot is readable + has expected tables
TABLE_COUNT=$(sqlite3 "$SNAPSHOT_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
if [[ "$TABLE_COUNT" -lt 10 ]]; then
    log "ERROR: snapshot has only $TABLE_COUNT tables (expected 15+). Aborting."
    exit 1
fi
log "Snapshot OK ($TABLE_COUNT tables)"

# 2. Push to QNAP via SSH key auth (primary path)
log "Pushing snapshot to QNAP via SSH ($QNAP_USER@$QNAP_HOST:$QNAP_REMOTE_DIR)"

# Ensure remote directory exists (idempotent mkdir -p)
ssh -o BatchMode=yes -o ConnectTimeout=10 "$QNAP_USER@$QNAP_HOST" \
    "mkdir -p '$QNAP_REMOTE_DIR'" 2>>"$LOG_FILE" || {
    log "ERROR: SSH connection or mkdir failed. BatchMode=yes means no password prompt — verify key auth."
    exit 2
}

# rsync over SSH. The trailing slash on the dest dir matters; we send a single file.
rsync -av -e "ssh -o BatchMode=yes -o ConnectTimeout=10" \
    --no-perms --chmod=u=rwX,g=rX,o=r \
    "$SNAPSHOT_FILE" \
    "${QNAP_USER}@${QNAP_HOST}:${QNAP_REMOTE_DIR}/" 2>>"$LOG_FILE" || {
    log "ERROR: rsync over SSH failed"
    exit 3
}

log "rsync complete"

# 3. Retention: delete NAS snapshots older than RETENTION_DAYS (remote find + rm)
log "Applying retention (remove snapshots older than $RETENTION_DAYS days)"
ssh -o BatchMode=yes -o ConnectTimeout=10 "$QNAP_USER@$QNAP_HOST" \
    "find '$QNAP_REMOTE_DIR' -maxdepth 1 -name 'state-*.db' -mtime +$RETENTION_DAYS -delete" 2>>"$LOG_FILE" || \
    log "WARNING: retention cleanup failed (non-fatal)"

# 4. Cleanup local snapshot
rm -f "$SNAPSHOT_FILE"

# 5. Summary
NAS_COUNT=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$QNAP_USER@$QNAP_HOST" \
    "ls -1 '$QNAP_REMOTE_DIR'/state-*.db 2>/dev/null | wc -l" 2>/dev/null | tr -d ' ' || echo "?")
NAS_SIZE=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$QNAP_USER@$QNAP_HOST" \
    "du -sh '$QNAP_REMOTE_DIR' 2>/dev/null | awk '{print \$1}'" 2>/dev/null || echo "?")
log "Backup complete. NAS now holds $NAS_COUNT snapshots ($NAS_SIZE)."

log "Done."

# ==============================================================================
# SMB FALLBACK (commented out — kept as documentation + recovery path)
# ==============================================================================
# If SSH key auth ever fails, you can fall back to SMB by uncommenting this block
# and replacing the SSH-based steps above. SMB requires keychain access, which is
# unreliable from launchd/cron contexts — that's why SSH is primary.
#
# QNAP_SHARE="HermesBackups"
# MOUNT_POINT="/Volumes/HermesBackups"
#
# log "Mounting $QNAP_SHARE via SMB"
# if mount_smbfs "//$QNAP_USER@$QNAP_HOST/$QNAP_SHARE" "$MOUNT_POINT" 2>>"$LOG_FILE"; then
#     log "Mounted via mount_smbfs"
# else
#     log "mount_smbfs failed, trying Finder via AppleScript..."
#     MOUNT_RESULT=$(osascript -e "tell application \"Finder\" to try
#         mount volume \"smb://$QNAP_HOST/$QNAP_SHARE\"
#         delay 2
#         return \"OK\"
#     on error errMsg
#         return \"ERR: \" & errMsg
#     end try" 2>&1)
#     [[ "$MOUNT_RESULT" == "OK" ]] || { log "ERROR: SMB mount failed: $MOUNT_RESULT"; exit 2; }
# fi
#
# rsync -av --no-perms "$SNAPSHOT_FILE" "$MOUNT_POINT/hermes-backups/state-db/"
#
# cleanup() { umount "$MOUNT_POINT" 2>/dev/null || true; }
# trap cleanup EXIT
