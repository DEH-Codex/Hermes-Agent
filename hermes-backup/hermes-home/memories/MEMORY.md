_Promoted from short-term recalls. Long-tail facts live in ~/memory/ (QMD). Pointer files indexed by QMD._
§
---
§
Identity: **Hermes** · Front door (intake, scoring, delegation) · Owner: John · TZ: America/Chicago
§
User-preference: **Personable + Professional.** Warm tone, substance. Don't narrate "let me check" — deliver action first. Trust John's stated values; one source-of-truth lookup; don't propose alternatives unless asked.
§
**Memory routing:** Long-tail facts in `~/memory/{decisions,environment,projects,skills,users}/` (QMD). Built-in MEMORY.md holds only every-turn essentials. If a fact is project/procedure-specific, it belongs in a project file or skill — NOT here.
§
**Bot Swarm v4 pointers:** HERMES=`nemotron-3.5-lightning:30b-mlx` (LOCAL). 9 profiles, 7 local / 2 cloud (NEO=deepseek-v4-flash:cloud fast tier, CORNELIUS=kimi-k2.7-code:cloud heavy tier). **HERMES, SAGAN, CENTURION and TUFTE all share ONE resident copy of nemotron-3.5-lightning — the `reasoning_effort` tier (minimal/medium/high/none) is what differentiates them.** Warm set = lightning ~23GB + granite ~12GB + lfm2.5 ~6GB = ~41GB, `OLLAMA_MAX_LOADED_MODELS=3`, nothing evicts. **`model.ollama_num_ctx` does NOT actually cap a model's load context — verified.** Hermes requires **≥64,000** context for tool use (`MINIMUM_CONTEXT_LENGTH`), so 65536 is the floor, never a tuning-down lever. Model binding lives in `~/.hermes/profiles/<bot>/config.yaml` — NOT `profile.yaml` (that holds only UI meta + kanban description) and NOT the `model:` block in config.yaml (a mirror, not the source). Verify with `hermes profile list`. Full roster, accounts, banned providers, qwen3.8:27b hang fix → `~/memory/projects/bot-swarm-v2.md`. **NEVER route `:cloud` to admin@jdsdirect.com (free tier).** All cloud bills to milotheassistant@gmail.com (Pro, $20/mo, auto-reload off).
§
**Ollama routing:** `provider: ollama-cloud` blocks need `base_url: https://ollama.com/v1` + `api_key: ${OLLAMA_API_KEY}`. Delegation block: `base_url: http://localhost:11434/v1` (empty → 404). Apply to providers AND `auxiliary.*`. Full: `~/memory/projects/ollama-routing.md`.
§
Cron: `~/.hermes/cron/jobs.json` is the only source of truth; cron sessions pass `skip_memory=True`. pwsh via Hermes terminal strips `$` in inline `pwsh -Command '$x=...'` → parser errors; write a `.ps1` (write_file) and run `pwsh -NoProfile -File /tmp/x.ps1` for any `$`-bearing script. Full: `~/memory/environment/hermes-gotchas.md`.
§
**Skill mapping:** DEH-903→`deh903`; computer-use→`computer-use`; UDM-Pro DNS: Policy Table→DNS radio→Host(A).
§
**Kanban:** Local `hermes kanban` at `~/.hermes/kanban.db`. `todo` doesn't hold (auto-promotes). Always check live sticky-blocked cards; skill loader may pick `linear`, dismiss it.
§
**Skill archive:** 8 skills archived to `~/.hermes/skills/.archive/` 2026-08-27 (catalog 125→118, ~177 catalog tokens saved): `docx`, `xlsx`, `powerpoint`, `pdf`, `ocr-and-documents`, `pokemon-player`, `minecraft-modpack-server`, `godmode`. Each has a per-skill `hermes curator rollback <id>` ledger entry. Restore via `hermes curator restore <name>`.
§
Hermes Gateway hang (proven 2026-08-23): macOS kqueue selector wedges when httpx leaves a CLOSE-WAIT FD registered — kevent() never fires on CLOSE-WAIT, so the asyncio loop blocks. Outbound sends still work. Fix: restart gateway; permanent: short httpx keepalive_expiry or external watchdog. See skills/hermes-gateway-hang-diagnostic.
§
M365: John's tenant 9575ab0b-5bfe-4ab2-abd1-4f4261cc5931, mailbox-only delegated (Mail.ReadWrite). Never re-initiate interactive login on cleanup — reuse CurrentUser token cache (m365-admin skill).