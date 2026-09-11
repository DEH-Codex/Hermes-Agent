# HEARTBEAT.md — Milo periodic checks

Run silently. Only surface something if it genuinely needs John's attention.
Reply HEARTBEAT_OK if nothing needs surfacing.

## Checks

- Scan Mission Control Approvals board for unresolved approvals older than 24h
- Check if any specialist agent sessions ended with an undelivered failure or error
- Review sync-decisions cron last run — if it errored, note it
- If today is Monday: remind John of any open decisions from the prior week (Decision_Log.md)
