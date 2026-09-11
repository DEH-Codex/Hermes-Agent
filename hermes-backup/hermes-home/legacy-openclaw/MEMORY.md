# MEMORY.md - Long-Term Memory

_Promoted from short-term recalls by the Memory Dreaming system._

---

## Identity
- **Name:** Milo
- **Role:** Executive Assistant — front door, intake, score, dispatch
- **Owner:** John
- **First contact:** 2026-03-28

## Key Facts
- Timezone: America/Chicago (CDT)
- Default model: openai-codex/gpt-5.4
- Milo (main) model override: ollama/glm-5.1:cloud

## Projects
- **DFB (Daily Financial Briefing):** Cron job at 8:45am weekdays, model=openai/gpt-5.4, isolated session, Vercel-only deployment
- **DFB website:** https://daily-brief-tau.vercel.app
- **CristalsCandies:** https://cristalscandies.vercel.app

## Agents
| Agent | Model | Role |
|-------|-------|------|
| Milo | glm-5.1:cloud | Front door |
| Sentinel | glm-5.1:cloud | Security |
| Cornelius | qwen3-coder-next | Coding |
| Cortana | qwen3.5:4b | Lightweight/sandbox |
| Neo | qwen3-coder-480b (NIM) | Heavy coding |
| Sagan | sonar-reasoning-pro | Research |
| Hermes | glm-5.1:cloud | Delivery |

## Preferences
- Vercel-only for DFB — no Discord posting
- 2-agent pipeline: single session does everything (no sub-agent spawning from cron)
- trash > rm
- Internal actions free, external actions require intent

## Infrastructure
- Host: Milo's Mac mini (Darwin 25.5.0 arm64)
- Workspace: /Volumes/BotCentral/Users/milo/.openclaw/workspace
- 2Brain wiki: /Volumes/BotCentral/Users/milo/repos/2Brain/wiki/
- Website repo: /Volumes/BotCentral/Users/milo/GitHub/MiloTheAssistant-Milo/website/

## Promoted From Short-Term Memory (2026-04-27)

<!-- openclaw-memory-promotion:memory:memory/2026-04-22.md:1:1 -->
- DEC-006 pushed at 2026-04-22 14:30 [score=0.814 recalls=0 avg=0.620 source=memory/2026-04-22.md:1-1]
