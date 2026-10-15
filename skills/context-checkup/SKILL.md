---
name: context-checkup
description: Audit what auto-loads into an agent session's context window and suggest lean, reversible fixes to cut startup tokens.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "1.3"
---

# Context checkup

Find what loads **automatically** into the session's context at startup, quantify it, and propose
**reversible** trims ranked by payoff — shrink the startup context window by cutting what isn't
worth its tokens. Read-only — measure and recommend; change settings only on explicit approval.

## Mental model (spend attention top-down)

Cost hierarchy, biggest first:
1. **MCP tool schemas** — large, but **deferred** by tool search. Only a problem if tool search is
   OFF.
2. **Always-on text** — every always-on instruction file (entry-file chain, `@imports`, unscoped
   rules files) and **skill/agent/command descriptions**: every available one's description
   loads every session, except skills flagged non-model-invocable (their description never
   loads; a manual-only skill costs nothing until invoked).
3. **MCP server instructions** — load per enabled server at startup; a chatty preamble can dwarf its
   tool names.
4. **MCP tool names** — ~10 tokens each. Cheap; 30 names ≈ 300 tokens isn't worth a recommendation.

Rules: **measure, never guess** — `wc`/count each source, convert with tokens ≈ words × 1.3 for
prose and characters / 4 otherwise, and state that rule once in the table header. When the agent
has a built-in context breakdown command, ask the user to paste its output and use its numbers as
the baseline; estimate only what it does not break down. **Rank by tokens-saved × reversibility.**
Distinguish **auto-loaded** from **lazy-linked** (nested AGENTS.md referenced from a parent are
*not* loaded — don't flag them).

Tool-name counts, the skills/agents/commands lists, and tool-search status come from the **session's
system-reminders**, not disk — read them from your own context.

## Checklist

Mechanics below are one agent's (settings keys, `~/.claude` paths, which `CLAUDE_CONFIG_DIR`
relocates); on another agent, map each item to its equivalent or ask.

**0. Verify tool search is on first.** Evidence is the session itself: MCP tools listed as deferred
(names only, searched on demand) means on, even once a search has pulled some schemas in; full
schemas loaded from the start means off, and every "names are cheap" conclusion flips. Only then
read the env var or setting (`ENABLE_TOOL_SEARCH`, incl. `auto:N` threshold modes) to explain why.

**1. Always-on instruction files.** Measure the entry-file chain (`CLAUDE.md`, `.claude/CLAUDE.md`,
`CLAUDE.local.md`, or `AGENTS.md` and `.claude/AGENTS.md` when read natively) in the project and
**every parent dir up to root**, the user-level entry file (`~/.claude/CLAUDE.md`), the
managed-policy one (a file such as `/Library/Application Support/ClaudeCode/CLAUDE.md` or
`/etc/claude-code/CLAUDE.md`, or the managed `claudeMd` setting), and every rules file,
subdirectories and symlinks included, in the project and user rules dirs (`.claude/rules/`,
`~/.claude/rules/`) that is not path-scoped — a project-rules symlink leading outside the project
only once external imports are approved. Expand `@import` lines (recursive). `wc -w` each; an
`AGENTS.md` or the user-level file counts once, whether read natively, imported or met on the
parent walk.

**2. Descriptions (often the largest unexamined chunk).** Skim the in-session lists of **skills,
subagent types, and slash commands** — their descriptions are always loaded, except
non-model-invocable skills (see Mental model). Many rarely-used entries = standing cost. When the
agent offers a skills list with token sizes or a visibility override, take the sizes from it; the
override (e.g. Claude Code's `skillOverrides`) hides a description without editing the skill.

**3. MCP servers.** From `.mcp.json` + settings, list enabled servers. Count tool **names** per
server; note any server with long **instructions**. Flag servers irrelevant to the user's work.

**4. Enablement levers and hooks.** Read `~/.claude/settings.json`, project
`.claude/settings.json`, `.claude/settings.local.json`. Check `enableAllProjectMcpServers`,
`enabledMcpjsonServers`, `enabledPlugins`. Precedence: managed > local > project > user. Each
plugin can pull in MCP servers, skills, agents, hooks. Measure `SessionStart` hook output (from
its script, or a run the user approves) as a startup cost, and per-prompt `UserPromptSubmit`
output as a cost per turn. Tool hooks' plain stdout stays out of the context, but their
`additionalContext` enters it, a cost per matching tool call.

**5. Memory.** Lines of the memory index up to the agent's load cap (e.g. the first 200 lines or
25KB of `MEMORY.md`, whichever comes first); topic files load on demand and are not a startup
cost.

## Output

A short sizes table (source → ≈ tokens → auto-loaded? → relevant to user's work?), then a
prioritized action list. For each action give the exact setting/file edit, the rough savings, and
how to reverse it (prefer per-session toggles). Skip anything under ~a few hundred tokens unless
asked to be exhaustive. Each action names the skill that performs it when installed (look in the
agent's skills and plugin dirs, as manual-only skills are missing from the in-session list), with
this skill's own namespace prefix if any: a fat entry file → `/agentify-project` (slimming into
docs); a fat memory index → `/memory-doctor`. Then ask before editing.

## Useful probes

```bash
# always-on instruction files: entry-file chain up to /, user-level and managed entry files, unscoped rules
c=${CLAUDE_CONFIG_DIR:-$HOME/.claude}; d=$PWD; while :; do for f in AGENTS.md .claude/AGENTS.md CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md; do [ "$d/$f" = "$c/CLAUDE.md" ] || { [ -f "$d/$f" ] && wc -w "$d/$f"; }; done; [ "$d" = / ] && break; d=$(dirname "$d"); done
wc -w "$c/CLAUDE.md" "/Library/Application Support/ClaudeCode/CLAUDE.md" /etc/claude-code/CLAUDE.md 2>/dev/null
find -L .claude/rules "$c/rules" -name '*.md' -exec grep -L '^paths:' {} + 2>/dev/null | tr '\n' '\0' | xargs -0 -r wc -w
# enabled MCP + settings
cat .mcp.json; cat .claude/settings.json .claude/settings.local.json "$c/settings.json" 2>/dev/null
```
