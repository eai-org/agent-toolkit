---
name: context-checkup
description: Audit what auto-loads into an agent session's context window and suggest lean, reversible fixes to cut startup tokens.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.2"
---

# Context checkup

Find what loads **automatically** into the session's context at startup, quantify it, and propose
**reversible** trims ranked by payoff — shrink the startup context window by cutting what isn't
worth its tokens. Read-only — measure and recommend; change settings only on explicit approval.

## Mental model (spend attention top-down)

Cost hierarchy, biggest first:
1. **MCP tool schemas** — large, but **deferred** by tool search. Only a problem if tool search is
   OFF.
2. **Always-on text** — CLAUDE.md/AGENTS.md chain, `@imports`, and **skill/agent/command
   descriptions** (every available one's description loads every session).
3. **MCP server instructions** — load per enabled server at startup; a chatty preamble can dwarf its
   tool names.
4. **MCP tool names** — ~10 tokens each. Cheap; 30 names ≈ 300 tokens isn't worth a recommendation.

Rules: **measure, never guess** — `wc`/count, then attach a rough token figure to each finding.
**Rank by tokens-saved × reversibility.** Distinguish **auto-loaded** from **lazy-linked** (nested
AGENTS.md referenced from a parent are *not* loaded — don't flag them).

Tool-name counts, the skills/agents/commands lists, and tool-search status come from the **session's
system-reminders**, not disk — read them from your own context.

## Checklist

**0. Verify tool search is on first.** If `ENABLE_TOOL_SEARCH` is disabled, MCP schemas load eagerly
and every "names are cheap" conclusion flips. Check this before anything else.

**1. Always-on docs.** Measure the CLAUDE.md/AGENTS.md chain: project file + **every parent dir up
to root** + global `~/.claude/CLAUDE.md`. Expand `@import` lines (recursive). `wc -w` each.

**2. Descriptions (often the largest unexamined chunk).** Skim the in-session lists of **skills,
subagent types, and slash commands** — their descriptions are always loaded. Many rarely-used
entries = standing cost.

**3. MCP servers.** From `.mcp.json` + settings, list enabled servers. Count tool **names** per
server; note any server with long **instructions**. Flag servers irrelevant to the user's work.

**4. Enablement levers.** Read `~/.claude/settings.json`, project `.claude/settings.json`,
`.claude/settings.local.json`. Check `enableAllProjectMcpServers`, `enabledMcpjsonServers`,
`enabledPlugins`. Precedence: managed > local > project > user. Each plugin can pull in MCP servers,
skills, agents, hooks.

**5. Memory.** Size of `MEMORY.md` index.

## Output

A short sizes table (source → ≈ tokens → auto-loaded? → relevant to user's work?), then a
prioritized action list. For each action give the exact setting/file edit, the rough savings, and
how to reverse it (prefer per-session toggles). Skip anything under ~a few hundred tokens unless
asked to be exhaustive. Then ask before editing.

## Useful probes

```bash
# always-on doc chain (run from project root; also check parent dirs + ~/.claude/CLAUDE.md)
for f in CLAUDE.md AGENTS.md ../CLAUDE.md ~/.claude/CLAUDE.md; do [ -f "$f" ] && wc -w "$f"; done
# enabled MCP + settings
cat .mcp.json; cat .claude/settings.json .claude/settings.local.json ~/.claude/settings.json 2>/dev/null
```
