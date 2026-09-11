# Hermes Agent — full removal checklist

Inventoried 2026-09-11 on the BotCentral Mac (`$HOME=/Volumes/BotCentral/Users/milo`).
Order is load-bearing: **nothing in Phase 2+ runs until Phase 0 is verified.**
Tick each box as you go. Commands assume `zsh` as `milo`.

---

## Phase 0 — Backups verified (gate)

- [ ] Git branch `claude/hermes-agent-removal-backup-3d86f9` pushed to `fork` (DEH-Codex) with `hermes-backup/` committed
- [ ] `wip/pre-removal-main-2026-09-11` pushed to `fork` (main's 4 uncommitted files)
- [ ] All worktree branches pushed to `fork` — unpushed at inventory time:
  - `fix/desktop-route-dashboard-not-serve` (9 commits — **this is the live gateway/desktop worktree**)
  - `codex/fix-desktop-background-sync-fixture` (1)
  - `codex/hermes-review-pr12-14-remediation` (1)
  ```bash
  cd ~/repos/hermes-agent && for b in fix/desktop-route-dashboard-not-serve codex/fix-desktop-background-sync-fixture codex/hermes-review-pr12-14-remediation codex/hermes-stack-v2 codex/hermes-stack-v2-phase2 codex/task5p-offline codex/task5q-offline claude/interesting-hertz-0ddec4 claude/hermes-agent-removal-backup-3d86f9 wip/pre-removal-main-2026-09-11; do git push fork "$b:$b"; done
  ```
- [ ] Local archive `~/hermes-archive-2026-09-11/` contains and verifies:
  - `hermes-agent-all-branches.bundle` — `git bundle verify` passes (every branch, incl. unpushed commits)
  - `hermes-home-full.tar.zst` — entire `~/.hermes` (3.3 GB), `tar -tf` succeeds
  - `md-backup/` — mirror of `hermes-backup/` from the git branch
  - `launchagents/` — the 4 plists (unredacted)
  - `Hermes-desktop-app.zip` — `.worktrees/hermes-stack-v2-v0204/apps/desktop/release/mac-arm64/Hermes.app`
  - `SHA256SUMS` matches
- [ ] Archive moved off BotCentral to the archive volume (needs sudo; MiloCache root is root-owned):
  ```bash
  sudo mkdir -p /Volumes/MiloCache/hermes-archive-2026-09-11 && sudo chown milo:staff /Volumes/MiloCache/hermes-archive-2026-09-11 && rsync -a --info=progress2 ~/hermes-archive-2026-09-11/ /Volumes/MiloCache/hermes-archive-2026-09-11/ && (cd /Volumes/MiloCache/hermes-archive-2026-09-11 && shasum -a 256 -c SHA256SUMS)
  ```
- [ ] Nobody else is using the CLI: `pgrep -fl 'hermes send|hermes chat|hermes_cli'` shows only the gateway/dashboard (Cursor sandbox `hermes send` was cleared by Grok Bot 2026-09-11)

---

## Phase 1 — Stop everything that runs

### 1a. Hermes Desktop (Electron, launched from inside the repo)
- [ ] Quit **Hermes** from the menu bar / Dock (Cmd-Q)
- [ ] Remove Login Item: System Settings → General → Login Items → remove **Hermes**
      (or `osascript -e 'tell application "System Events" to delete login item "Hermes"'`)
- [ ] Verify: `pgrep -fl 'Hermes.app'` → empty

### 1b. launchd agents (user domain)
- [ ] `ai.hermes.gateway` — gateway (Telegram/Matrix/etc. connections, internal cron ticker)
- [ ] `ai.hermes.dashboard` — dashboard on 127.0.0.1:9119 (+ 3 `mcp_stdio_watchdog` children each for gateway & dashboard)
- [ ] `com.milo.hermes-backup` — currently failing (exit 1)
- [ ] `com.hermes.qnap-backup` — nightly `state.db` rsync to QNAP 192.168.1.5
  ```bash
  for l in ai.hermes.gateway ai.hermes.dashboard com.milo.hermes-backup com.hermes.qnap-backup; do launchctl bootout gui/$(id -u)/$l 2>/dev/null; rm -f ~/Library/LaunchAgents/$l.plist; done
  ```
- [ ] Verify: `launchctl list | grep -i hermes` → empty

### 1c. Hermes-internal cron (lives in `~/.hermes/cron/jobs.json`; dies with the gateway)
Archived in `hermes-backup/hermes-home/cron/jobs.json` for re-creation. At inventory:
- [ ] enabled: `m365-token-warm` (08:00 M-F), `ollama-maintain` (Sun 03:00), `optimize-for-ai-hourly`, `sqlite-memory-reindex` (every 5m)
- [ ] disabled: `daily-telegram-briefing`, `lifestyle-brief-9am-weekend`, `market-brief-845am-weekdays`, `brief-weekday-morning`, `brief-saturday`, `brief-sunday`, `brief-sunday-audit`
- [ ] Note: `ollama-maintain` calls `~/.hermes/bin/ollama-maintain.sh` — if you want Ollama maintenance to continue after removal, move that script somewhere else and schedule it via launchd. Archived copy: `hermes-backup/hermes-home/scripts/ollama-maintain.sh`.
- [ ] No user `crontab` entries exist (verified) — nothing to do there

### 1d. Orphan processes
- [ ] `pkill -f mcp_stdio_watchdog.py`
- [ ] `pkill -f 'ui-tui/dist/entry.js'` (the `~/.hermes/node` TUI)
- [ ] `pkill -f 'hermes_cli'`
- [ ] Verify: `pgrep -fl -i hermes | grep -v -E 'grep|Claude'` → empty
- [ ] Leave alone: `mcp-proton-bridge.py` (pid ran under the repo venv — it will die when the venv goes; re-launch it from another Python if it's still needed by non-Hermes tooling)

---

## Phase 2 — Remove code

- [ ] `~/.local/bin/hermes` → symlink into the v0204 worktree venv. `rm ~/.local/bin/hermes`
- [ ] `~/.local/bin/hermes-acp` → `rm`
- [ ] **Keep** `~/.local/bin/gmail-mcp`, `~/.local/bin/mcp-proton-bridge.py` — MCP servers, not Hermes (but `mcp-proton-bridge.py` was being run via the repo venv; check its shebang)
- [ ] `~/repos/hermes-agent` (9.1 GB, 9 worktrees, 2 venvs, desktop build). Only after Phase 0 ✔:
  ```bash
  cd ~/repos/hermes-agent && git worktree list   # eyeball one last time
  rm -rf ~/repos/hermes-agent
  ```
- [ ] Stale project entries (harmless, cosmetic): `~/.claude.json` (3 keys under `projects` for the repo/worktree paths), `~/.codex/config.toml` (`[projects."…/hermes-agent"]` + 1 line at ~264)

---

## Phase 3 — Remove state

- [ ] `~/.hermes` (3.3 GB) — only after `hermes-home-full.tar.zst` verified. Contents of note: `state.db`, `kanban.db`, `sessions/`, `sqlite-memory/` (721 MB), `state-snapshots/` (1.2 GB), `skills/` (54), `plugins/` (hermes-achievements, image_gen, perplexity), `legacy-openclaw/`, `migration/`, `rollback/`
  ```bash
  rm -rf ~/.hermes
  ```
  This also removes the two **symlinks** `~/.hermes/.env` and `~/.hermes/auth.json` — the targets in `/usr/local/var/hermes-secrets/` are untouched.
- [ ] Desktop app state:
  ```bash
  rm -rf ~/Library/Application\ Support/Hermes
  defaults delete com.nousresearch.hermes
  rm -rf ~/Library/Saved\ Application\ State/com.nousresearch.hermes.savedState 2>/dev/null
  ```
- [ ] Keychain (manual — **you** do this in Keychain Access, search "hermes"): `Hermes Safe Storage` (Electron cookie-encryption key) and `hermes-himalaya-proton` (Proton IMAP cred for the himalaya email skill). Delete `Hermes Safe Storage`; keep `hermes-himalaya-proton` if you'll re-enable the email skill.

---

## Phase 4 — Retained on purpose (do NOT remove)

| Item | Why |
|---|---|
| `/usr/local/var/hermes-secrets/` (`.env`, `auth.json`, `.env.bak.*`) | API keys + provider auth; fresh install re-symlinks `~/.hermes/.env` and `~/.hermes/auth.json` here |
| `~/.zshenv` "Hermes Model Orchestration" block | It's **Ollama** env (`OLLAMA_MAX_LOADED_MODELS=2`, `OLLAMA_CONTEXT_LENGTH=65536`, `OLLAMA_KEEP_ALIVE=10m`) — still wanted while Ollama runs |
| Ollama (`sh.brew.ollama` agent, 19 models incl. `qwen3-coder:30b`, `qwen3.8:27b`, `nomic-embed-text`) | Shared inference backend |
| OrbStack + all containers (trading-bot postgres/redis, cbt-concierge, deh-seaweed) | None are Hermes; `orb list` has no Linux machines |
| `com.digitalenergy.tradingbot.*`, `com.qmd.daemon`, `dev.agentcookie.source`, `com.milo.ssh-auth-sock`, Proton Mail Bridge | Unrelated launch agents |
| `~/.hermes/bin/uv`, `uvx` | Bundled copies; system `uv` (if any) is separate. Fresh install brings its own |
| QNAP `192.168.1.5:/share/HermesBackups/hermes-backups/state-db` | Historical `state.db` snapshots on the NAS — leave for now, prune later |
| Chrome/Cursor/Codex/Claude Code itself | Not Hermes |

---

## Phase 5 — Verification

```bash
which hermes                                   # → nothing
launchctl list | grep -i hermes                # → nothing
pgrep -fl -i hermes | grep -v -E 'grep|Claude' # → nothing
ls ~/.hermes ~/repos/hermes-agent 2>&1         # → No such file or directory ×2
ls ~/Library/LaunchAgents | grep -i hermes     # → nothing
defaults read com.nousresearch.hermes 2>&1     # → does not exist
osascript -e 'tell application "System Events" to get the name of every login item' | tr ',' '\n' | grep -i hermes  # → nothing
ls /usr/local/var/hermes-secrets               # → .env auth.json (still there — good)
ollama list | head -3                          # → still works
```

---

## Reinstall notes (for later, official path)

- Install from the official NousResearch instructions into a clean `~/.hermes` + wherever the installer puts source.
- Re-seed: `SOUL.md`, `memories/MEMORY.md`, `memories/USER.md` from `hermes-backup/hermes-home/`.
- Re-link secrets: `ln -sf /usr/local/var/hermes-secrets/.env ~/.hermes/.env` and same for `auth.json`.
- Re-create the 4 enabled cron jobs from `cron/jobs.json` (prompts/schedules are all in there).
- `config.yaml` from the archive tarball is a *reference*, not a drop-in — the fresh install's schema may have moved. Diff, don't copy.
- Do **not** re-import `legacy-openclaw/` or run `hermes claw migrate` with `--migrate-secrets` (old Discord token; see memory `hermes-migration-plan`).
