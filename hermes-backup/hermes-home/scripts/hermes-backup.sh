#!/bin/bash
set -uo pipefail

export HOME=/Volumes/BotCentral/Users/milo
export PATH=/Volumes/BotCentral/Users/milo/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin

backup_dir=/Volumes/MiloCache/backups/hermes
mkdir -p "$backup_dir"

today="$backup_dir/hermes-$(date +%Y%m%d).zip"
log="$backup_dir/backup.log"
err="$backup_dir/backup.err.log"

{
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] starting Hermes backup"
  hermes backup -o "$today"
  ls -t "$backup_dir"/hermes-*.zip 2>/dev/null | tail -n +15 | xargs rm -f --
  test -s "$today"
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] backup complete: $today"
} >>"$log" 2>>"$err"
