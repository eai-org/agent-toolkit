# Agent matrix

What agentify-project knows about each agent. Deliberately not a pre-researched database: only the
Claude row ships verified. Any other agent's facts are researched **at runtime** against that
agent's current official docs, only when the agent is detected (or named by the user) and a
selected area needs its specifics. Confirm research findings with the user before use;
inconclusive research means ask — never guess. Persist recipes that matter to teammates in the
project's onboarding doc.

## Columns

| Column | Content |
| --- | --- |
| Agent | Name |
| Detection traces | Files/dirs that indicate the agent is used in this repo |
| Entry file(s) | e.g. CLAUDE.md, GEMINI.md, `.github/copilot-instructions.md` |
| Include syntax | The pointer mechanism, or "none → duplicate content" |
| Project skills dir | e.g. `.claude/skills/`; or "reads `.agents/skills` natively → no link" |
| Gitignore entries | Agent-specific artifact dirs/files worth ignoring |

## Verified rows

A row older than six months is re-checked against the agent's official docs before use, like any
researched agent.

| Agent | Detection traces | Entry file(s) | Include syntax | Project skills dir | Gitignore entries |
| --- | --- | --- | --- | --- | --- |
| Claude Code | `CLAUDE.md`, `.claude/` | `AGENTS.md` directly (v2.1.277+) unless a `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` exists in the working directory or above — then those only | `@AGENTS.md` import in a kept CLAUDE.md; Claude-specific lines may follow it | `.claude/skills/` | `.claude/plans/**`, `.claude/worktrees/**`, `.claude/settings.local.json`, `.claude/__pycache__`, `CLAUDE.local.md` |

Claude notes (verified against the official memory docs, 2026-10):

- AGENTS.md support (v2.1.277+) is the built-in `agents-md` plugin (`cc-plugin-agents-md@builtin`
  from v2.1.285); the **Project instructions** setting defaults to `claude-md-or-agents-md`,
  `claude-md-and-agents-md` loads both. When and whether to keep a CLAUDE.md pointer:
  target-structure §2. `InstructionsLoaded` hooks fire for an imported AGENTS.md, not for one read
  directly.
- `@` imports load at launch — recursive, max 4 hops, relative to the containing file — and do
  **not** reduce context; hence AGENTS.md references docs with plain links, never imports. Only
  `@`-prefixed paths import; backticked paths do not.
- Windows symlinks need admin/Developer Mode, so the `@AGENTS.md` import beats a symlink as the
  default CLAUDE.md pointer.
- `.claude/rules/` (path-scoped via `paths:` frontmatter) and nested CLAUDE.md files are
  Claude-specific progressive disclosure — rules content is candidate material for governing docs.

## Detection traces to scan for

Well-known traces of agents commonly met — indicative starting points, not a research checklist. A
trace can be tool-generated rather than agent usage (an Nx migration writes `.cursor/mcp.json`):
corroborate with that agent's rules files or commit trailers before wiring it.

| Agent | Traces |
| --- | --- |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Cursor | `.cursorrules`, `.cursor/` |
| Gemini CLI | `GEMINI.md`, `.gemini/` |
| Windsurf | `.windsurfrules`, `.windsurf/` |
| Cline | `.clinerules` |
| OpenCode | `opencode.json`, `.opencode/` |

Codex, Kimi Code, Amp and others may leave no unique project trace (several agents read the
neutral AGENTS.md natively); when the user names one, research it like any detected agent.
AGENTS.md itself is agent-neutral — never treat it as a trace.
