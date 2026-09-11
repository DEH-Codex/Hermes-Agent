# Email Plumbing — M365 + Google Admin Skills

**Author:** Milo (drafted 2026-08-12) · **Status:** Awaiting John's sign-off · **Scope:** Phase 1 (admin plumbing) + Phase 2 (personal-mail read/send)

## Verified ground truth (already on this box)

| Surface | State | Evidence |
|---|---|---|
| `m365-admin` skill | Exists in `~/repos/CodexMasterSkills/skills/m365-admin/SKILL.md` (8.9 KB, 147 lines). No `agents/` content. Not yet copied into `~/.hermes/skills/`. | `ls -la` |
| `google-admin` skill | Exists in `~/repos/CodexMasterSkills/skills/google-admin/SKILL.md` (9.9 KB, 142 lines). No `agents/` content. Not yet copied into `~/.hermes/skills/`. | `ls -la` |
| `protonmail` skill | Older skill in same repo + **already wired** as `proton-milo` MCP server in `~/.hermes/config.yaml`. `mcp_proton_milo_*` tools are live in this session. | `hermes mcp list` |
| Gmail (personal) | **Already wired** as `gmail-milo` MCP server. `~/.gmail-mcp-milo/credentials.json` holds valid OAuth tokens (access_token, refresh_token, expiry_date, scope present). `mcp_gmail_milo_*` tools are live. | `hermes mcp list` + token-file inspection |
| Google Calendar | **Already wired** as `google-calendar` MCP server. | `hermes mcp list` |
| Microsoft Graph / Outlook / Exchange Online | **Not wired.** No MCP, no PowerShell module, no app registration. | absent from config |
| Google Workspace Admin SDK / Directory API | **Not wired.** No MCP, no `gws` CLI, no service account, no OAuth client. | absent from config |

## The core reality check (must read before signing off)

The two new skills you pointed me at (`m365-admin`, `google-admin`) are **tenant-admin** skills — they manage *other people's* accounts, groups, licenses, domains, audit logs, and security policy. They are **not** inbox skills.

Gmail and Proton already give you read+send on your personal mailboxes. So "get into email" splits into two distinct problems:

- **Phase 1 — Admin plumbing:** give the `m365-admin` and `google-admin` skills the runtime tools they need (Microsoft Graph PowerShell / EXO module on the Mac, Google Workspace Admin SDK via `gws` CLI or a service account) so you can inspect/manage tenants. No real auth tokens get created until you point me at a specific tenant.
- **Phase 2 — Personal mail polish:** confirm Gmail MCP send actually works (read is wired; send is the unverified one), then add **Microsoft Graph personal-mail** read+send so an M365 mailbox shows up alongside Gmail/Proton. This is the "Outlook inbox" you don't have yet.

I'll not touch any of this until you pick a lane on the remaining unknowns. See "Open questions" below.

---

## Phase 1 — Admin plumbing (M365 + Google Workspace)

### 1A. Bring both skills into the live Hermes skill tree

Copy them from `~/repos/CodexMasterSkills/skills/` into `~/.hermes/skills/` and verify they pass the frontmatter validator.

```bash
# Stage to a staging path first; do not overwrite silently
mkdir -p ~/.hermes/skills/inbox
cp -v ~/repos/CodexMasterSkills/skills/m365-admin/SKILL.md    ~/.hermes/skills/inbox/m365-admin.md
cp -v ~/repos/CodexMasterSkills/skills/google-admin/SKILL.md ~/.hermes/skills/inbox/google-admin.md
```

Validate (uses the same rules as `tools/skill_manager_tool.py::_validate_frontmatter`):

```bash
python3 -c '
import yaml, re, pathlib
for f in ["~/.hermes/skills/inbox/m365-admin.md", "~/.hermes/skills/inbox/google-admin.md"]:
    p = pathlib.Path(f).expanduser()
    c = p.read_text()
    assert c.startswith("---"), f"{f}: missing leading ---"
    m = re.search(r"\n---\s*\n", c[3:])
    fm = yaml.safe_load(c[3:m.start()+3])
    assert "name" in fm and "description" in fm
    assert len(fm["description"]) <= 1024, f"{f}: description too long"
    assert len(c) <= 100_000, f"{f}: too big"
    print(f"OK {f} ({len(c)} bytes, desc {len(fm[\"description\"])} chars)")
'
```

After validation passes, move to final location and commit:

```bash
mkdir -p ~/.hermes/skills/admin
mv ~/.hermes/skills/inbox/m365-admin.md    ~/.hermes/skills/admin/m365-admin.md
mv ~/.hermes/skills/inbox/google-admin.md ~/.hermes/skills/admin/google-admin.md
# Restart not required; skills are picked up on next session per the hermes-agent skill.
```

**Pitfall to flag in the SKILL.md files:** both currently mention `governance-review` and `secret-hygiene` skills — those exist as in-repo skills in the same `CodexMasterSkills` repo. I'll grep to confirm before the install, and patch the cross-refs if needed.

### 1B. Microsoft 365 admin runtime

Three viable paths; need John's pick:

| Path | Pros | Cons | Cost |
|---|---|---|---|
| **A. Microsoft Graph PowerShell (Core)** | `pwsh` likely already installed via Homebrew; least-privilege scope per command via `Find-MgGraphCommand`; works with interactive MFA. | Per-session sign-in; no MCP layer (commands run via `execute_code` subprocess). | Free. |
| **B. Microsoft Graph MCP server** | First-class tools auto-loaded into Hermes; persistent auth via app registration. | Requires an Azure AD app registration + client secret (John must create in Entra admin center); I cannot create it for you. | Free. Adds tenant object. |
| **C. EXO v3 + Graph PowerShell on the Mac** | Covers shared mailboxes and mail-flow, which Graph does not. | PowerShell on macOS is `pwsh` only — some cmdlets assume Windows. | Free. |

**Default if John doesn't pick: A** (Graph PowerShell Core via `pwsh`, used via `execute_code` calls; no new MCP). This avoids creating an Azure app registration until John wants persistent auth.

### 1C. Google Workspace admin runtime

| Path | Pros | Cons | Cost |
|---|---|---|---|
| **A. `gws` CLI (brew install googleworkspace-cli)** | Schema + dry-run support, JSON output, OAuth flow built in. | Adds a brew formula. Auth still requires a Google Cloud OAuth client. | Free. |
| **B. Google Workspace Admin MCP server** | First-class tools. | Same OAuth client requirement; less mature ecosystem than Graph's MCP. | Free. |
| **C. Admin SDK via curl/scripts** | No new tooling. | Lots of glue code; no schema help. | Free. |

**Default if John doesn't pick: A** (`gws` via Homebrew, with admin OAuth client created when first used). Avoids persisting a service account.

### 1D. Tenant credentials — **no real values until you tell me which tenant**

For both platforms, Phase 1 is **read-only install + docs refresh**. No live tenant commands run until John says "tenant X, account Y, do Z." All commands are gated by the `stop-and-ask` language in the skills themselves.

---

## Phase 2 — Personal mail (Gmail + Outlook)

### 2A. Gmail — confirm send works, leave read as-is

The `gmail-milo` MCP server is already wired. Per the `@shinzolabs/gmail-mcp` README (will verify via Context7), the tool set includes `gmail_send_message` and friends. A read-only smoke test from this session:

```python
# In an execute_code block, after /reset so tools are current:
mcp_gmail_milo_list_messages(maxResults=1, q="newer_than:7d")
```

**Won't run a send test** until John says "send a test to <address>."

### 2B. Outlook / Microsoft Graph personal-mail — NEW

Add a second `mcp__*` server, e.g. `outlook-milo`, that wraps Microsoft Graph endpoints `/me/messages`, `/me/sendMail`, `/me/mailFolders`. Two prerequisite steps John must do (I cannot do these):

1. Register an Azure AD app in Entra (single-tenant, "Accounts in this organizational directory only") with delegated permissions `Mail.Read`, `Mail.Send`, `User.Read`. Set redirect URI to `http://127.0.0.1` (loopback) or `https://localhost` (device code).
2. Create a client secret, copy the **value** (not the secret ID) and the **client ID** and **tenant ID** to a new file `~/.config/codex_skills/outlook-graph.env` (chmod 600).

Once those exist, install the MCP server. Three options:

| Server | Notes |
|---|---|
| **`@softeria/msgraph-mcp`** (community) | npm-installable, supports device-code auth. **Pinning to this unless John says otherwise.** |
| `microsoft-graph-mcp` (official-ish) | Less maintained. |
| Roll our own (15-line stdio wrapper) | Full control, no new dependency. |

After install, add to `~/.hermes/config.yaml` under `mcp_servers:`:

```yaml
outlook-milo:
  command: /opt/homebrew/bin/msgraph-mcp
  env:
    MSGRAPH_CLIENT_ID: ${OUTLOOK_CLIENT_ID}
    MSGRAPH_CLIENT_SECRET: ${OUTLOOK_CLIENT_SECRET}
    MSGRAPH_TENANT_ID: ${OUTLOOK_TENANT_ID}
```

…and reload MCP (`hermes` will respawn on next session; `/reset` if in-session).

---

## Open questions — need John's answers before any real wire-up

1. **Phase 1B path** — A (Graph PowerShell on the Mac), B (Graph MCP), or C (EXO + Graph)? **Default: A.**
2. **Phase 1C path** — A (`gws` CLI), B (Workspace Admin MCP), or C (curl scripts)? **Default: A.**
3. **Phase 1 tenants** — Is there a specific M365 / Google Workspace tenant you want to point these at, or is Phase 1 strictly "get the tools installed, no live tenant calls yet"? **Default: install only, no live calls.**
4. **Phase 2B prerequisites** — Do you already have an Azure AD app registration suitable for personal-mail read+send, or do you need a step-by-step on creating one in Entra? **Default: I'll write a step-by-step; you click the buttons.**
5. **Proton bridge** — the existing `proton-milo` MCP server's tool set in this session includes `mcp_proton_milo_get_message`, `list_folders`, `move_message`, `search_messages`, `send_message`. Anything missing you want from the Proton side? **Default: leave as-is, it's working.**

---

## Verification plan (after each phase)

- **Phase 1 install:** `python3 -c 'import yaml,...'` validator passes; `hermes skills list` shows both; restart session; `/skill m365-admin` loads without error.
- **Phase 1B runtime:** `pwsh -c 'Get-Module -ListAvailable Microsoft.Graph'` returns ≥ 1 module. No live tenant call yet.
- **Phase 1C runtime:** `gws --version` returns a version. `gws schema admin.users.list` returns schema. No live tenant call yet.
- **Phase 2A:** `mcp_gmail_milo_list_messages(maxResults=1)` returns one message; do NOT send until John approves.
- **Phase 2B:** `mcp_outlook_milo_get_profile()` returns the user identity (no mailbox read). `mcp_outlook_milo_list_messages` returns ≥ 1 message. Send test only after John approves a target address.

## What I will NOT do without explicit OK

- Create Azure AD app registrations, client secrets, or consent grants.
- Create or download Google service-account keys.
- Run any destructive or write command against a live tenant.
- Send a real email from any account.
- Commit anything to `~/repos/CodexMasterSkills/` without John reviewing the diff first.
