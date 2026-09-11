# [Hermes Gateway] Telegram long-poll wedges on macOS — recurring silent hang

**Filed:** 2026-08-23
**Reporter:** Milo (via Hermes)
**Status:** Open — workaround in place, root cause identified, fix not yet implemented
**Severity:** High (production impact — Telegram inbound silently stops)

---

## Summary

The `hermes gateway` process on macOS periodically enters a "silently deaf" state where it stays alive but stops receiving Telegram messages. Restart fixes it; hang recurs within 15-30 minutes.

---

## Symptom

- Process stays alive (`ps` shows 0.0-0.1% CPU, normal memory)
- `gateway.log` stops being written (mtime frozen for hours)
- Outbound Telegram sends via `hermes send` still work (return valid `message_id`)
- Inbound Telegram messages never processed — no `inbound message:` log lines
- No crash, no `exit_nonzero` — gateway stays alive but stops receiving
- Restart fixes it; hang recurs within 15-30 minutes

---

## Root cause

Confirmed via `sudo sample <pid> 1 -mayDie` on the hung process. The Python stack trace shows:

```
Main thread (com.apple.main-thread):
  builtin_exec
  → _PyEval_EvalFrameDefault
  → select_kqueue_control_impl
  → kevent  (in libsystem_kernel.dylib)
```

All 20 threads are in waiting states. The macOS kqueue selector has the Telegram long-poll file descriptor registered but **no events fire on it**. The asyncio event loop is permanently blocked in `kevent()`.

This is the "wedged getUpdates consumer" condition that the existing `_polling_heartbeat_loop` (`plugins/platforms/telegram/adapter.py:3105`) is designed to detect. **But the heartbeat coroutine is itself part of the broken asyncio event loop.** When `kevent` doesn't return, even `await asyncio.sleep(90)` doesn't tick, so the heartbeat never runs.

The relevant comment in the source already calls this out:

```python
# From _polling_heartbeat_loop:
"When the underlying TCP connection enters CLOSE-WAIT
(the remote sent a FIN but the httpx pool has not yet
noticed), epoll still reports the socket as readable
and no exception is raised — so PTB's error_callback
never fires and the gateway silently stops receiving
messages."
```

The comment says "epoll reports readable" but the stack trace shows zero events firing on any FD — likely a macOS kqueue vs Linux epoll behavioral difference. **Either way, the end result is identical: gateway stops receiving messages.**

---

## Reproduction

Reliable reproduction (after ~30 minutes of gateway uptime):

```bash
# Confirm hang:
ps -p $(pgrep -f 'hermes_cli.main gateway' | head -1) -o pid,stat,etime,%cpu
# Process alive, CPU ~0%

stat -f '%Sm' /Volumes/BotCentral/Users/milo/.hermes/logs/gateway.log
date -u
# Log mtime frozen for hours

# Confirm symptom — outbound works, inbound doesn't:
hermes send -t "telegram:Hermes HQ / scratch" "outbound test $(date)" --json
# Returns: {"success": true, "mirrored": true, "message_id": 161}

# Then send from iPhone in any topic and watch gateway.log
# (no inbound log line will appear, no session update in state.db)
```

---

## Impact

Production: Telegram inbound delivery stops working while the gateway looks healthy. Affects any user who relies on Telegram as their primary Hermes channel.

---

## Proposed fix candidates

Investigation suggests three approaches, in order of how invasive they are:

1. **Tune httpx keepalive** (least invasive) — set `keepalive_expiry` on the httpx transport to ~30s so Telegram's long-poll connection is recycled before it can wedge. httpx's default behavior may keep connections alive across the gateway's stability window in a way that exposes the macOS kqueue bug.

2. **External watchdog** (band-aid) — a cron job that checks `gateway.log` mtime against current time; if no new lines for >5 minutes, restart. Doesn't fix the bug, but recovers automatically.

3. **Force selector refresh** (proper fix) — recreate the asyncio selector on a timer, or use `Selector.select()` improvements from Python 3.13+. Most invasive; requires Python upgrade.

A less-explored option: **switch the Telegram adapter from python-telegram-bot to a direct httpx-based polling loop**, since PTB's abstraction layer may be hiding the FD state from the selector. This is the most invasive but would eliminate the class of bugs.

---

## Investigation artifacts

- Stack trace: `/tmp/gateway_hang_sample_2026-08-23.txt`
- Diagnostic skill: `~/.hermes/skills/hermes-gateway-hang-diagnostic/SKILL.md`
- Reference source: `plugins/platforms/telegram/adapter.py:3105` (`_polling_heartbeat_loop`), `:3219` (`_probe_pending_updates`)

---

## Workaround (until fix lands)

```bash
launchctl bootout gui/501/ai.hermes.gateway
sleep 2
launchctl bootstrap gui/501 ~/Library/LaunchAgents/ai.hermes.gateway.plist
sleep 10
tail -5 ~/.hermes/logs/gateway.log  # should show "Telegram polling confirmed healthy"
```

The launchd `KeepAlive` plist already handles this for actual crashes, but the silent hang doesn't trigger a restart — it requires manual intervention.

---

## Filing notes

This ticket was drafted on 2026-08-23 while no Linear API key was available locally. It is stored at `~/.hermes/tickets/gateway-hang-2026-08-23.md` until it can be filed into Linear. To file:

1. Get a Linear API key from **Settings > API > Personal API keys**
2. `hermes config set LINEAR_API_KEY <your-key>`
3. Tell Hermes "file the ticket" — the same content will be posted via the Linear GraphQL API
