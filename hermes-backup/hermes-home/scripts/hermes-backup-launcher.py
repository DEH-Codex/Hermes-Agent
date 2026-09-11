#!/Volumes/BotCentral/Users/milo/repos/hermes-agent/.venv/bin/python
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


HOME = Path("/Volumes/BotCentral/Users/milo")
BACKUP_DIR = Path("/Volumes/MiloCache/backups/hermes")
HERMES = HOME / ".local/bin/hermes"
PATH = f"{HOME}/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"


def log_line(message: str) -> None:
    timestamp = datetime.now().astimezone().strftime("%Y-%m-%dT%H:%M:%S%z")
    print(f"[{timestamp}] {message}", flush=True)


def main() -> int:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    backup_path = BACKUP_DIR / f"hermes-{datetime.now().strftime('%Y%m%d')}.zip"

    env = os.environ.copy()
    env.update(
        {
            "HOME": str(HOME),
            "HERMES_HOME": str(HOME / ".hermes"),
            "PATH": PATH,
        }
    )

    log_line("starting Hermes backup")
    result = subprocess.run(
        [str(HERMES), "backup", "-o", str(backup_path)],
        cwd=str(HOME),
        env=env,
        text=True,
    )
    if result.returncode != 0:
        log_line(f"backup failed with exit code {result.returncode}")
        return result.returncode

    backups = sorted(BACKUP_DIR.glob("hermes-*.zip"), key=lambda p: p.stat().st_mtime, reverse=True)
    for old_backup in backups[14:]:
        old_backup.unlink(missing_ok=True)

    if not backup_path.exists() or backup_path.stat().st_size == 0:
        log_line(f"backup missing or empty: {backup_path}")
        return 1

    log_line(f"backup complete: {backup_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
