#!/usr/bin/env python3
"""Aggregate active kanban items for the daily briefing."""
import json
import subprocess
import sys

# Valid non-done statuses (per AGENTS.md guidance)
STATUSES = ["ready", "running", "review", "blocked", "scheduled", "todo", "triage"]
PER_STATUS_LIMIT = 50  # raw fetch cap
TOP_N = 5  # briefing cap

aggregated = []  # list of (status, item)
errors = []

for status in STATUSES:
    try:
        result = subprocess.run(
            ["hermes", "kanban", "list", "--status", status, "--json"],
            capture_output=True,
            text=True,
            timeout=20,
        )
        if result.returncode != 0:
            errors.append(f"{status}: exit {result.returncode} - {result.stderr.strip()[:120]}")
            continue
        out = result.stdout.strip()
        if not out:
            continue
        try:
            items = json.loads(out)
        except json.JSONDecodeError as e:
            errors.append(f"{status}: json parse - {e}")
            continue
        if not isinstance(items, list):
            # some CLIs wrap in {"items": [...]} or {"tasks": [...]}
            if isinstance(items, dict):
                for key in ("items", "tasks", "data", "results"):
                    if key in items and isinstance(items[key], list):
                        items = items[key]
                        break
                else:
                    errors.append(f"{status}: unexpected shape {type(items).__name__}")
                    continue
            else:
                errors.append(f"{status}: unexpected shape {type(items).__name__}")
                continue
        for it in items:
            aggregated.append((status, it))
    except subprocess.TimeoutExpired:
        errors.append(f"{status}: timeout")
    except Exception as e:
        errors.append(f"{status}: {type(e).__name__}: {e}")

# Count totals
by_status = {s: 0 for s in STATUSES}
for s, _ in aggregated:
    by_status[s] += 1

# Pick top 5 — sort by priority hint if present, else preserve order
def priority_key(t):
    # Lower number = higher priority. Look for priority field; else 99
    _, item = t
    p = item.get("priority") if isinstance(item, dict) else None
    if isinstance(p, (int, float)):
        return p
    # Try to infer from status
    s, _ = t
    order = {"running": 0, "review": 1, "blocked": 2, "ready": 3, "scheduled": 4, "todo": 5, "triage": 6}
    return order.get(s, 99)

# Compose the final list: prioritize running/review/blocked first, then ready/scheduled/todo/triage
def urgency_rank(t):
    s, _ = t
    order = {"running": 0, "review": 1, "blocked": 2, "ready": 3, "scheduled": 4, "todo": 5, "triage": 6}
    return order.get(s, 99)

sorted_items = sorted(aggregated, key=urgency_rank)
top = sorted_items[:TOP_N]

# Serialize top items as compact one-liners
def oneliner(t):
    s, item = t
    if not isinstance(item, dict):
        return f"[{s}] {item}"
    title = item.get("title") or item.get("name") or item.get("summary") or "<untitled>"
    eid = item.get("id") or item.get("uid") or item.get("key") or ""
    due = item.get("due") or item.get("due_date") or item.get("deadline")
    project = item.get("project") or item.get("board") or ""
    parts = [f"[{s}] {title}"]
    if due:
        parts.append(f"due {due}")
    if project and project != "default":
        parts.append(f"({project})")
    if eid:
        parts.append(f"#{eid}")
    return " · ".join(parts)

output = {
    "totals": by_status,
    "total_active": sum(by_status.values()),
    "top": [{"status": s, "item": it, "line": oneliner((s, it))} for s, it in top],
    "errors": errors,
}

print(json.dumps(output, indent=2, default=str))
