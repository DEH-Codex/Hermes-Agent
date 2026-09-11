# Hermes Agent Model Stack Rework v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the active Hermes installation to the exact stable v0.20.1 release, make NVIDIA Nemotron 3 Ultra through NVIDIA NIM the lead/orchestrator, make OpenAI Codex the coding-specialist profile, retain the local Nemotron delegate, and remove Anthropic and OpenRouter from every active runtime route.

**Architecture:** The default profile plans and orchestrates with hosted Nemotron Ultra, delegates local work to Nemotron 3.5 Lightning, and fails over through Ollama Cloud. The `coder` profile uses the Hermes-native OpenAI Codex provider with the full AIAgent tool surface. Text-only auxiliary work, vision, MoA, voice, and update automation are configured independently so a failure or entitlement issue in one lane does not silently reroute another lane to an unapproved provider.

**Tech Stack:** Hermes Agent v0.20.1 (`v2026.8.13`), Python virtual environment, macOS launchd, NVIDIA NIM, OpenAI Codex OAuth, Ollama Cloud, local Ollama/MLX, xAI OAuth or local voice, YAML configuration, Hermes profiles, Hermes cron.

| Handoff field | Value |
|---|---|
| Prepared | 2026-08-15 |
| Target machine | Mac Mini M4 Pro, 64 GB |
| Canonical repository | `/Volumes/BotCentral/Users/milo/repos/hermes-agent` |
| Hermes home | `/Volumes/BotCentral/Users/milo/.hermes` |

## Global Constraints

1. No Anthropic or Claude model may remain in an **active** model, fallback, auxiliary, MoA, voice, preset, or profile route.
2. No OpenRouter route may remain active after cutover. Do not delete its credential until all replacement routes pass and Milo separately approves credential removal.
3. Use the canonical provider IDs: `nvidia`, `openai-codex`, `ollama-cloud`, and `xai-oauth`. Bare `ollama` means local/custom Ollama; `xai` means direct API-key billing.
4. Do not invent `excluded_providers` or built-in `enabled: false` settings. Hermes v0.20.1 does not expose a supported switch that removes built-in providers from the picker. The enforceable contract is no active routes, no usable credentials, and no post-cutover outbound calls.
5. Keep the lead and coder on Hermes' native AIAgent runtime. For the coder profile use `/codex-runtime auto`; do not force Codex App Server, because that runtime lacks Hermes-native `delegate_task`, `memory`, `session_search`, and `todo`.
6. The system prompt and tool surface must stay stable during a conversation. Do not implement routing by rebuilding either mid-session.
7. Preserve the local delegate `nemotron-3.5-lightning:30b-mlx` unless a live host-side check proves it unavailable.
8. Do not expose secrets in command output, the repository, logs, screenshots, or this handoff. Enter API keys only through Hermes' secret-aware flow or the ignored Hermes `.env` file.
9. Every phase ends at its gate. If a gate fails, stop, record evidence, and roll back only that phase.
10. Preserve the dirty canonical checkout. Do not discard, stash, overwrite, or commit unrelated user work.
11. This document authorizes documentation only. Execution is a separate request. Push, merge, installation repointing, launchd writes/restarts, OAuth login, API-key creation/removal, paid API fallback, and cron creation each require the authority stated in the relevant phase.
12. Do not create recurring update automation by default. Phase 10 is optional and approval-gated.

---

## 1. Verified Starting Point

These facts were observed while preparing v2. Re-run the commands because they are point-in-time state.

| Item | Observed state |
|---|---|
| Canonical branch | `main`, tracking `origin/main` |
| Canonical HEAD | `56000cc29df3333419dc73c60b27bd660b2ecca2` |
| Installed Hermes | v0.16.0 / v2026.6.5 |
| Executable | `/Volumes/BotCentral/Users/milo/.local/bin/hermes` |
| Executable target | `.claude/worktrees/musing-borg-8b8f32/.venv/bin/hermes` |
| Executing worktree | detached, clean, same observed HEAD |
| Canonical worktree | dirty; contains user-owned edits and untracked files |
| Fork remotes | `origin` and `milo` both point to `DEH-Codex/Hermes-Agent` |
| Official upstream remote | absent |
| Latest approved target | official v0.20.1, tag `v2026.8.13` |
| Default model | `minimax-m3:cloud` through `ollama-cloud` |
| Coder model | `kimi-k2.7-code:cloud` through `ollama-cloud` |
| Gateway | launchd service running before execution (PID 33817; v0.16 `musing-borg-8b8f32` command); do not repoint or restart during Phase 0 |
| NVIDIA NIM | `NVIDIA_API_KEY` missing |
| OpenAI Codex | Hermes OAuth not logged in |
| xAI | API key present; xAI OAuth not logged in |
| Cron | six active jobs out of eight; no update job approved |

Known dirty paths at preparation time:

```text
M  plans/hermes-migration-brief-v2-streams-A-E.md
D  website/docs/user-guide/skills/optional/research/research-bioinformatics.md
?? .brief/
```

The current installed updater is risky in this layout: it runs from a detached nested worktree but attempts to check out `main`, while `main` is already checked out in the canonical root. Do not run `hermes update` until Phase 1 resolves the source layout.

Sandboxed checks could not validate provider networking, local Ollama, or host auth locks. Treat `hermes doctor` and `ollama` results from the preparation session as inconclusive; rerun them in Milo's normal host terminal.

## 2. Target Runtime Map

| Role | Provider | Preferred model | Required fallback or note |
|---|---|---|---|
| Lead/orchestrator | `nvidia` | exact live NIM ID for Nemotron 3 Ultra 550B-A55B | Discover from `/v1/models`; expected form `nvidia/nemotron-3-ultra-550b-a55b` |
| Lead fallback 1 | `ollama-cloud` | `glm-5.2` | Validate exact live tag |
| Lead fallback 2 | `ollama-cloud` | `deepseek-v4-flash` | Validate exact live tag |
| Coder profile | `openai-codex` | `gpt-5.6-sol` | Use `gpt-5.5` only if the live Codex catalog does not expose 5.6-sol |
| Delegated subagents | local Ollama | `nemotron-3.5-lightning:30b-mlx` | Unchanged |
| Vision | `ollama-cloud` | `minimax-m3:cloud` or exact live equivalent | Explicitly pinned; Nemotron Ultra is text-only |
| Text auxiliaries | `ollama-cloud` | `deepseek-v4-flash` | Pin each supported auxiliary slot explicitly |
| MCP auxiliary | `ollama-cloud` | `glm-5.2` | Explicitly pinned |
| MoA reference A | `openai-codex` | selected Codex model | Same selected coder model |
| MoA reference B | `ollama-cloud` | `glm-5.2` | |
| MoA aggregator | `ollama-cloud` | `deepseek-v4-pro` | No Claude/OpenRouter |
| X search | `xai-oauth` | live supported Grok model | Subscription route only unless paid API use is approved |
| TTS/STT | `xai-oauth` if entitled; otherwise local | live xAI voice or Piper + faster-whisper | Never silently fall back to `xai` API-key billing |

## 3. Approval Map

| Action | Approval required before execution? |
|---|---|
| Read-only git, config, status, catalog, and log inspection | No |
| Create backup archive | No |
| Create an isolated local worktree/branch | Yes, as part of an explicit execution request |
| Add official upstream remote and fetch tag | Yes, as part of the upgrade phase |
| Edit local Hermes config/profile files | Yes, as part of the cutover phase |
| OAuth login or NVIDIA credential setup | Yes; interactive external auth |
| Change the installed executable or launchd service | Yes; machine runtime mutation |
| Restart gateway | Yes; service interruption |
| Use xAI direct API key after OAuth 403 | Separate paid-usage approval |
| Delete Anthropic/OpenRouter/OpenAI Platform secrets | Separate credential-removal approval |
| Push, merge, or open a PR | Separate repository/publication approval |
| Create recurring update cron | Separate automation approval; default is skip |

## 4. Phase 0 — Baseline, Evidence, and Backup

**Purpose:** Capture the real host state without changing it, then create a restorable Hermes data archive.

- [ ] From the canonical repository, record worktree and remote state:

  ```bash
  cd /Volumes/BotCentral/Users/milo/repos/hermes-agent
  git status --short --branch
  git rev-parse HEAD
  git remote -v
  git worktree list --porcelain
  ```

- [ ] Record the executable chain and runtime version:

  ```bash
  command -v hermes
  ls -l "$(command -v hermes)"
  hermes --version
  hermes status
  hermes gateway status
  hermes cron list
  ```

- [ ] Run host-side health/config checks and save redacted results in the execution record:

  ```bash
  hermes doctor
  hermes config check
  hermes config show
  hermes auth list
  ollama list
  ollama ps
  ```

- [ ] Confirm the canonical dirty paths are still user-owned. Stop if new overlap appears in files the upgrade must modify.

- [ ] Create both a quick named state snapshot and a full archive. Record their absolute paths and checksums:

  ```bash
  hermes backup --quick --label "pre-stack-v2"
  hermes backup -o /Volumes/BotCentral/Users/milo/hermes-backup-pre-stack-v2.zip
  shasum -a 256 /Volumes/BotCentral/Users/milo/hermes-backup-pre-stack-v2.zip
  ```

**Gate 0**

- [ ] The canonical worktree was not modified by the baseline.
- [ ] Both backup commands succeeded and the full archive has a recorded SHA-256.
- [ ] `hermes config check` passes on the existing installation.
- [ ] The local delegate model is visible from the host, or the failure is documented before any cutover.
- [ ] Any `doctor` warning is classified as an existing issue, a host dependency, or a blocker.

**Rollback:** None required; this phase is read-only except for backup creation.

## 5. Phase 1 — Reconcile the Fork with Official v0.20.1

**Purpose:** Produce a tested upgrade branch without touching the dirty canonical working tree or relying on the installed nested worktree's updater.

**Files:** repository metadata and an isolated worktree only. Do not edit the user-owned dirty paths.

- [ ] Verify `.worktrees/` is ignored before creating a repository-local worktree:

  ```bash
  cd /Volumes/BotCentral/Users/milo/repos/hermes-agent
  git check-ignore -q .worktrees
  ```

  If this returns nonzero, stop and choose an explicitly approved external worktree path. Do not add ignore rules as an incidental edit.

- [ ] With upgrade authorization, add the official remote only if absent and fetch the exact tag:

  ```bash
  git remote add upstream https://github.com/NousResearch/hermes-agent.git
  git fetch upstream tag v2026.8.13
  git show --no-patch --decorate v2026.8.13
  ```

- [ ] Record the fork delta before choosing integration strategy:

  ```bash
  git log --left-right --cherry-pick --oneline v2026.8.13...main
  git diff --stat v2026.8.13...main
  git log --all --oneline --decorate --grep='Telegram\|topic\|forum'
  ```

- [ ] Review the fork's Telegram/forum-topic work, including the history associated with the previously referenced custom PRs #12–#15. Determine which commits are still absent upstream. Preserve original authorship.

- [ ] Create an isolated upgrade worktree and branch from the exact official tag:

  ```bash
  mkdir -p .worktrees
  git worktree add .worktrees/hermes-stack-v2 -b codex/hermes-stack-v2 v2026.8.13
  ```

- [ ] Reapply only confirmed fork-specific commits using merge, rebase, or cherry-pick based on the recorded delta. Do not reimplement external work if its commit can be preserved.

- [ ] Install dependencies inside the isolated worktree's `.venv` and run the repository's validation script:

  ```bash
  cd /Volumes/BotCentral/Users/milo/repos/hermes-agent/.worktrees/hermes-stack-v2
  python3 -m venv .venv
  source .venv/bin/activate
  python -m pip install -e ".[all]"
  scripts/run_tests.sh
  ```

- [ ] Run focused Telegram/forum-topic tests in addition to the full applicable suite. Record exact commands and counts.

- [ ] Prepare a commit/PR handoff, but do not push, merge, or repoint the installation without separate approval.

**Gate 1**

- [ ] Upgrade worktree identifies as Hermes v0.20.1 / v2026.8.13.
- [ ] Required fork-specific behavior is present with contributor history preserved.
- [ ] Focused and applicable full tests pass.
- [ ] Canonical root still has exactly its pre-existing user-owned changes.
- [ ] The installed v0.16.0 executable and gateway remain untouched.

**Rollback:** Remove only the new isolated worktree and branch after confirming their exact paths and only if Milo authorizes cleanup. The old install remains active.

## 6. Phase 2 — Install the Validated Upgrade and Repoint Services

**Purpose:** Make the validated v0.20.1 fork build the canonical installed Hermes runtime.

- [ ] Obtain explicit approval for the final branch integration, executable repoint, and launchd change.

- [ ] Integrate the reviewed upgrade through the chosen repository workflow. Do not merge over the dirty root; preserve or relocate its user-owned changes through an agreed workflow first.

- [ ] Create or refresh a canonical `.venv` from the integrated commit:

  ```bash
  cd /Volumes/BotCentral/Users/milo/repos/hermes-agent
  python3 -m venv .venv
  source .venv/bin/activate
  python -m pip install -e ".[all]"
  ```

- [ ] Repoint `/Volumes/BotCentral/Users/milo/.local/bin/hermes` through the supported installer or an explicit, verified symlink update. Resolve the target before replacing anything; it must end under the canonical repository, not `.claude/worktrees/musing-borg-8b8f32`.

- [ ] Regenerate the launchd service using the v0.20.1 executable. Preserve the old plist as a recoverable copy before replacement.

- [ ] Migrate and validate config without changing model routes yet:

  ```bash
  hermes config migrate
  hermes config check
  hermes config show
  hermes --version
  hermes doctor
  ```

- [ ] Start or restart the gateway only after the executable and plist targets are verified:

  ```bash
  hermes gateway install
  hermes gateway restart
  hermes gateway status
  ```

- [ ] Send one smoke-test chat through the **old model routing** before changing providers.

**Gate 2**

- [ ] `command -v hermes`, symlink resolution, the launchd program path, and `hermes --version` all point to the canonical v0.20.1 install.
- [ ] `hermes doctor` and `hermes config check` are clean or have explicitly accepted non-routing warnings.
- [ ] The gateway responds and one old-stack chat succeeds.
- [ ] No model-stack change has yet been made.

**Rollback:** Repoint the executable and launchd plist to the recorded pre-upgrade targets, restart the gateway, and verify v0.16.0. Do not delete the new checkout or Hermes home.

## 7. Phase 3 — Authenticate and Prove Each Provider Independently

**Purpose:** Validate credentials, entitlements, exact model IDs, and billing boundaries before editing the active routing graph.

### 7.1 NVIDIA NIM

- [ ] Create or obtain an NVIDIA NIM key with explicit approval. Store it as `NVIDIA_API_KEY`; do not use the v1 name `NVIDIA_NIM_API_KEY`.
- [ ] Select provider `nvidia` in `hermes model`, or use the secret-aware config flow. Do not define a custom `nvidia-nim` provider unless the built-in provider is demonstrably broken.
- [ ] Query the authenticated live NIM model catalog without printing the key and record the exact Nemotron Ultra slug.
- [ ] Send a one-shot response test with the discovered model:

  ```bash
  hermes chat -Q -q "Reply with exactly: NIM_OK" --provider nvidia -m <LIVE_NIM_MODEL_ID>
  ```

- [ ] Run a real Hermes task that performs at least two sequential tool calls. Hosted NIM tool calling must be proven, not inferred from its OpenAI-compatible API.

For a future **self-hosted** NIM deployment, the server requires auto tool choice and the matching parsers:

```text
--enable-auto-tool-choice --tool-call-parser qwen3_coder --reasoning-parser nemotron_v3
```

This flag note does not apply to NVIDIA's managed hosted endpoint.

### 7.2 OpenAI Codex

- [ ] Authenticate Hermes' own Codex credential pool. A separate Codex CLI login does not replace this step:

  ```bash
  hermes auth add openai-codex
  hermes auth list
  ```

- [ ] Inspect the live Codex model catalog. Select `gpt-5.6-sol` if exposed; otherwise record `gpt-5.5` as the approved fallback.
- [ ] Send a one-shot test with the selected model:

  ```bash
  hermes chat -Q -q "Reply with exactly: CODEX_OK" --provider openai-codex -m <SELECTED_CODEX_MODEL>
  ```

### 7.3 Ollama Cloud and local Ollama

- [ ] Validate the cloud catalog and exact tags for `glm-5.2`, `deepseek-v4-flash`, `deepseek-v4-pro`, and MiniMax M3.
- [ ] Send a one-shot test through `ollama-cloud` for each target model.
- [ ] Prove the local delegate through local Ollama, not `ollama-cloud`.

### 7.4 xAI billing boundary

- [ ] With approval, authenticate the subscription route using the canonical provider:

  ```bash
  hermes auth add xai-oauth
  hermes auth list
  ```

- [ ] Send a one-shot xAI OAuth test. If it returns HTTP 403 after successful authentication, record it as an entitlement/tier failure.
- [ ] Do **not** switch to provider `xai` or use `XAI_API_KEY` as fallback unless Milo explicitly approves usage-based API billing.

**Gate 3**

- [ ] NIM text and sequential tool calls pass.
- [ ] Codex returns through Hermes OAuth with the chosen live model.
- [ ] All required Ollama Cloud models and the local delegate pass independently.
- [ ] xAI is classified as `OAuth works`, `OAuth entitlement blocked`, or `not configured`; no paid fallback was silently activated.

**Rollback:** Remove only credentials created in this phase if Milo separately approves credential revocation. Otherwise leave credentials stored but keep active routing unchanged.

## 8. Phase 4 — Cut Over the Lead, Delegate, and Fallback Chain

**Purpose:** Make Nemotron Ultra the default orchestrator while preserving deterministic fallback and local delegation.

- [ ] Create a fresh quick snapshot before editing:

  ```bash
  hermes backup --quick --label "pre-lead-cutover"
  ```

- [ ] Update the default profile with the exact live model IDs:

  ```yaml
  model:
    provider: nvidia
    default: <LIVE_NIM_MODEL_ID>

  fallback_providers:
    - provider: ollama-cloud
      model: glm-5.2
    - provider: ollama-cloud
      model: deepseek-v4-flash
  ```

- [ ] Remove the deprecated singular `fallback_model` only after the list above validates.
- [ ] Confirm the delegation configuration still selects local `nemotron-3.5-lightning:30b-mlx`. Do not rewrite it as `ollama-cloud`.
- [ ] Keep Kanban's default and fallback assignee on `default`; do not make `coder` the blanket assignee.
- [ ] Validate config and restart the gateway with approval:

  ```bash
  hermes config check
  hermes gateway restart
  hermes gateway status
  ```

- [ ] Run an orchestration acceptance task that requires planning, a `delegate_task` call to the local subagent, a second tool call, and a merged final answer.
- [ ] Force or simulate a NIM failure and prove fallback 1, then fallback 2. Capture provider/model selection from logs without exposing prompts or secrets.
- [ ] Run a bounded soak test representative of Kanban auto-decomposition. Watch for NIM HTTP 429 responses and verify they do not cause an uncontrolled retry/delegation storm.

**Gate 4**

- [ ] The lead is `nvidia/<LIVE_NIM_MODEL_ID>`.
- [ ] The local delegate executes and the lead merges its result.
- [ ] Both fallbacks activate in order under controlled failure.
- [ ] NIM quota behavior is acceptable or the phase is rolled back.
- [ ] No Anthropic/OpenRouter request occurs in the post-cutover log window.

**Rollback:** Import the `pre-lead-cutover` snapshot or restore only the pre-phase `model`, fallback, and delegation sections, then restart and smoke test.

## 9. Phase 5 — Pin Auxiliary Models, Especially Vision

**Purpose:** Prevent the text-only lead from inheriting vision or side-task duties through `provider: auto`.

- [ ] Run `hermes config migrate` and inventory the auxiliary keys exposed by the installed v0.20.1 build.
- [ ] Use only keys present in the migrated schema. Do not use the v1 keys `extraction`, `triage`, or `web_summarization`; the supported equivalents include `web_extract` and `triage_specifier`.
- [ ] Pin the stable core slots as follows, using exact live model tags:

  ```yaml
  auxiliary:
    vision:
      provider: ollama-cloud
      model: minimax-m3:cloud
    web_extract:
      provider: ollama-cloud
      model: deepseek-v4-flash
    compression:
      provider: ollama-cloud
      model: deepseek-v4-flash
    skills_hub:
      provider: ollama-cloud
      model: deepseek-v4-flash
    mcp:
      provider: ollama-cloud
      model: glm-5.2
    title_generation:
      provider: ollama-cloud
      model: deepseek-v4-flash
    triage_specifier:
      provider: ollama-cloud
      model: deepseek-v4-flash
    kanban_decomposer:
      provider: ollama-cloud
      model: deepseek-v4-flash
    profile_describer:
      provider: ollama-cloud
      model: deepseek-v4-flash
  ```

- [ ] If v0.20.1 exposes additional side-task slots such as `memory_query_rewrite`, `goal_judge`, `curator`, `monitor`, `background_review`, `moa_reference`, or `moa_aggregator`, inventory their current resolution before deciding whether to pin them. Do not add unsupported keys.
- [ ] Treat `auxiliary.approval` separately because it affects a security boundary. Pin it to DeepSeek only after approval-mode tests confirm it is at least as conservative as the current route; otherwise retain the current known-good approval model.
- [ ] Validate config and restart the gateway.
- [ ] Upload a real image and verify accurate description. MiniMax M3 must be invoked as a single-shot vision auxiliary, not promoted to an agentic tool loop.
- [ ] Trigger web extraction, compression, MCP specification, title generation, triage, and Kanban decomposition; confirm each recorded provider/model.

**Gate 5**

- [ ] Real image input succeeds through MiniMax M3.
- [ ] Every exercised auxiliary resolves to its intended provider, never the NIM lead by `auto`.
- [ ] Approval behavior is unchanged or explicitly revalidated.
- [ ] No unsupported config key is present.

**Rollback:** Restore the pre-phase `auxiliary` block from the latest backup, validate, restart, and repeat the image gate before proceeding.

## 10. Phase 6 — Configure the Codex Coder Profile

**Purpose:** Make Codex the specialist for code while retaining Hermes-native memory, delegation, session search, and todo behavior.

**File:** `/Volumes/BotCentral/Users/milo/.hermes/profiles/coder/config.yaml`

- [ ] Back up the coder profile and preserve its coding-specialist description.
- [ ] Set the live selected Codex model:

  ```yaml
  model:
    provider: openai-codex
    default: <SELECTED_CODEX_MODEL>
  ```

- [ ] Start one coder session and run `/codex-runtime auto`. Verify no persisted setting forces App Server.
- [ ] Submit a bounded repository task whose expected route is `coder` and verify provider/model selection from runtime evidence.
- [ ] From inside the coder profile, exercise `memory`, `session_search`, `todo`, and one `delegate_task` call.
- [ ] Confirm general work still routes to `default`, not `coder`.

**Gate 6**

- [ ] Coding work selects the coder profile and the selected Codex model.
- [ ] All four Hermes-native capabilities remain usable.
- [ ] Default orchestration still owns non-coding tasks and Kanban fallback assignment.

**Rollback:** Restore the prior coder profile config and start a new session; profile configuration is session-scoped and should not be hot-swapped mid-conversation.

## 11. Phase 7 — Rewire Mixture of Agents

**Purpose:** Replace the legacy OpenRouter/Claude MoA with provider-aware v0.20.1 presets.

- [ ] Do not remove `OPENROUTER_API_KEY` before this phase. The v0.16.0 MoA implementation is hardwired to OpenRouter/Anthropic; the credential stays until the upgraded preset passes.
- [ ] Configure a named preset using the installed v0.20.1 schema:

  ```yaml
  moa:
    default_preset: default
    privacy_filter: display
    presets:
      default:
        reference_models:
          - provider: openai-codex
            model: <SELECTED_CODEX_MODEL>
          - provider: ollama-cloud
            model: glm-5.2
        aggregator:
          provider: ollama-cloud
          model: deepseek-v4-pro
        max_tokens: 4096
        enabled: true
  ```

- [ ] Confirm the installed schema uses `max_tokens`; do not carry forward an unrecognized `reference_max_tokens` key. If the exact release schema differs, follow `hermes config migrate` and the tag's documentation, then record the change.
- [ ] Leave temperature unset initially so each model uses its provider default.
- [ ] Invoke MoA on demand and capture evidence that both reference legs completed and `deepseek-v4-pro` aggregated them.
- [ ] Test one failed reference leg and confirm behavior is bounded and visible.
- [ ] Search only the post-test log interval for runtime provider calls.

**Gate 7**

- [ ] MoA returns two reference outputs and one aggregator result.
- [ ] The runtime calls only `openai-codex` and `ollama-cloud` for this preset.
- [ ] No Anthropic or OpenRouter call appears after the test start timestamp.

**Rollback:** Disable the new preset or restore the pre-phase MoA block. Do not re-enable the Claude aggregator merely to make the gate pass.

## 12. Phase 8 — Decide and Validate Voice/X Routing

**Purpose:** Remove dependence on OpenAI Platform voice APIs without turning a subscription entitlement failure into unapproved API charges.

- [ ] Present the Phase 3 xAI entitlement result to Milo.
- [ ] If `xai-oauth` works and the installed voice tools support the OAuth credential, configure xAI TTS/STT and X search through that subscription route.
- [ ] If OAuth returns 403, choose one of these only with explicit direction:

  1. Local/no-key route: Piper TTS plus local faster-whisper STT.
  2. Direct `xai` API-key route: usage-based billing; separately approved.

- [ ] For the local route, install Piper through `hermes tools`, then use a supported config equivalent to:

  ```yaml
  tts:
    provider: piper
  stt:
    provider: local
    local:
      model: small
  ```

- [ ] Verify one real voice-message round trip on an already configured channel.
- [ ] Verify X search independently and record whether it used `xai-oauth` or an explicitly approved alternative.

**Gate 8**

- [ ] Voice round trip succeeds.
- [ ] X search succeeds or is explicitly left disabled.
- [ ] No unapproved `xai` direct API request occurs.
- [ ] The OpenAI Platform voice key is no longer required by an active route.

**Rollback:** Restore the prior voice block only if retaining the old billable OpenAI Platform route is explicitly approved; otherwise disable voice while the local/xAI path is repaired.

## 13. Phase 9 — Retire OpenRouter and Anthropic from Active Use

**Purpose:** Enforce the hard routing constraint after every replacement path is proven.

- [ ] Create a final pre-cleanup quick snapshot.
- [ ] Search all active root/profile configuration for provider/model routes:

  ```bash
  rg -n -i "anthropic|claude|openrouter" \
    /Volumes/BotCentral/Users/milo/.hermes/config.yaml \
    /Volumes/BotCentral/Users/milo/.hermes/profiles
  ```

- [ ] Remove or replace every active route, fallback, auxiliary, preset, MoA leg, and profile result. Historical sessions, documentation, source code, and pre-cutover logs may still contain names; do not delete them to make a search pass.
- [ ] Confirm there is no supported `excluded_providers` switch in the installed release. Do not add one.
- [ ] With separate credential-removal approval, remove Anthropic and OpenRouter secrets from the Hermes secret store/`.env` and credential pool. Also remove the OpenAI Platform voice key if no active route uses it and Milo approves.
- [ ] Record a cutover timestamp, restart the gateway, run lead/coder/MoA/vision/voice smoke tests, and inspect only new logs for provider calls.
- [ ] Open `hermes model` and explain that built-in provider names may remain visible even when unusable. Picker visibility is not the acceptance criterion.

**Gate 9**

- [ ] No active configuration references Anthropic, Claude, or OpenRouter.
- [ ] No usable Anthropic/OpenRouter credential remains after approved removal.
- [ ] No outbound Anthropic/OpenRouter call appears after the cutover timestamp.
- [ ] Lead, coder, local delegate, fallback, vision, auxiliaries, MoA, and the chosen voice route still pass.

**Rollback:** Restore the pre-cleanup snapshot if an unrelated route breaks. Do not reactivate Anthropic/OpenRouter; repair the approved replacement route or pause that feature.

## 14. Phase 10 — Optional Weekly Update Check

**Default decision:** Skip. Prior direction was to avoid adding update automation without explicit approval.

If Milo later approves a check-only job:

- [ ] Confirm the gateway is intentionally running; Hermes cron scheduling depends on the gateway/service environment for reliable scheduled execution and delivery.
- [ ] Create a small executable script under `/Volumes/BotCentral/Users/milo/.hermes/scripts/` that runs `hermes update --check` and `hermes doctor` without applying an update.
- [ ] Test the script manually and ensure output contains no secrets.
- [ ] Schedule the script with current syntax:

  ```bash
  hermes cron create "0 9 * * 1" \
    --no-agent \
    --script /Volumes/BotCentral/Users/milo/.hermes/scripts/hermes-update-check.sh \
    --name "Hermes update check" \
    --deliver telegram
  ```

- [ ] Trigger the job manually, confirm delivery, and verify it did not update or restart Hermes.

**Gate 10**

- [ ] The job is check-only, test-triggered, and delivered to the approved destination.
- [ ] No update is automatically applied.
- [ ] If approval was not given, no job or script was created.

**Rollback:** Disable or delete only the named update-check job after confirming its exact ID. Leave the six existing active jobs untouched.

## 15. Full Rollback Procedure

Use this only if per-phase rollback is insufficient.

- [ ] Stop the gateway gracefully.
- [ ] Preserve the failed current Hermes home by moving it to a timestamped quarantine path. Never run `rm -rf ~/.hermes`.
- [ ] Import the recorded full archive:

  ```bash
  hermes import /Volumes/BotCentral/Users/milo/hermes-backup-pre-stack-v2.zip
  ```

- [ ] Repoint the executable and launchd plist to the recorded pre-upgrade v0.16.0 targets.
- [ ] Restart the gateway and verify version, config, old provider route, sessions, cron list, and channel delivery.
- [ ] Note that OAuth refresh-token rotation and external entitlement changes may not be fully reversible from a filesystem backup. Reauthenticate only when necessary and approved.

## 16. Final Acceptance Checklist

- [ ] Canonical repository is the active source and the executable no longer points into `musing-borg-8b8f32`.
- [ ] Hermes reports v0.20.1 / v2026.8.13.
- [ ] `hermes doctor` and `hermes config check` pass on the host.
- [ ] Gateway is in the intended running/stopped state and its launchd target is correct.
- [ ] Nemotron Ultra through `nvidia` performs sequential tool calls, delegates, and merges results.
- [ ] Local `nemotron-3.5-lightning:30b-mlx` remains the delegated subagent.
- [ ] `glm-5.2` and `deepseek-v4-flash` fallbacks fire in order.
- [ ] A real uploaded image is described through MiniMax M3.
- [ ] Every configured auxiliary task resolves to the intended non-NIM model.
- [ ] Coding work selects `coder` through `openai-codex`.
- [ ] `memory`, `session_search`, `todo`, and `delegate_task` work inside the coder profile.
- [ ] MoA completes two references plus the DeepSeek aggregator.
- [ ] Voice/X routing is subscription-backed, local, explicitly paid, or deliberately disabled.
- [ ] No active Anthropic/Claude/OpenRouter route or post-cutover call remains.
- [ ] Existing cron jobs are unchanged; update automation exists only if separately approved.
- [ ] All backup paths, commit SHAs, model IDs, timestamps, test commands, and results are recorded without secrets.

## 17. Open Decisions for Milo

1. **Exact NVIDIA model slug:** accept only the authenticated live NIM catalog result.
2. **NIM quota tolerance:** decide whether hosted NIM remains primary after the Kanban soak test; Ollama Cloud is a contingency, not an automatic substitution.
3. **Codex model:** use `gpt-5.6-sol` if live and entitled; otherwise approve `gpt-5.5`.
4. **xAI voice/search:** choose subscription OAuth, local voice, or explicitly paid direct API after the entitlement test.
5. **Provider picker visibility:** default is no core code change. Hiding inactive built-in providers would require a separately scoped product change.
6. **Credential deletion:** removal follows successful cutover and separate approval.
7. **Weekly update check:** default is no automation; opt in only after reviewing the exact script and delivery target.
8. **Repository publication:** choose whether the v0.20.1 reconciliation is merged/pushed through a PR after local validation.

## 18. Execution Evidence Template

For every phase, append a short record outside secret-bearing files:

```text
Phase:
Started/finished (America/Chicago):
Operator:
Repo SHA and branch:
Hermes version and executable target:
Config backup/archive and SHA-256:
Provider/model IDs exercised:
Commands run:
Tests and observed results:
Post-change log window:
Gate: PASS / FAIL
Rollback performed:
Approvals used:
Follow-ups:
```

## 19. Source References

- [Hermes Agent v0.20.1 release](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.13)
- [Hermes provider integration guide](https://github.com/NousResearch/hermes-agent/blob/v2026.8.13/website/docs/integrations/providers.md)
- [Hermes xAI OAuth guide](https://github.com/NousResearch/hermes-agent/blob/v2026.8.13/website/docs/guides/xai-grok-oauth.md)
- [Hermes Mixture of Agents guide](https://github.com/NousResearch/hermes-agent/blob/v2026.8.13/website/docs/user-guide/features/mixture-of-agents.md)
- [NVIDIA Nemotron 3 Ultra NIM tool-calling setup](https://docs.nvidia.com/nim/large-language-models/2.0.6/day-0/get-started-nemotron-3-ultra.html)
- [NVIDIA Nemotron 3 Ultra model card](https://build.nvidia.com/nvidia/nemotron-3-ultra-550b-a55b/modelcard)
- [Ollama MiniMax M3 catalog](https://ollama.com/library/minimax-m3%3Acloud)
