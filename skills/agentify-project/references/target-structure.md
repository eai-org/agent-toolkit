# Target structure

The converged end state agentify-project measures against and converges toward. The audit detects
each area's state; the menu offers the gaps.

## 1. AGENTS.md — canonical lean index

At repo root (plural, per the agents.md convention). Maximally lean — only the irreducible
minimum: project one-liner, universal build/test/run commands, hard constraints the code cannot
reveal (e.g. module boundaries, what must never import what — never a directory tree or
architecture overview, which the agent derives and which go stale), the linked docs index, and the
planning-dir convention. Keep-vs-extract test per block: *part of that minimum?* Everything else —
even generic categories nearly every session reads (testing, conventions, architecture, …) — gets
its own governing doc: often-loaded linked docs are fine, a fat entry file is not. Reference docs
as **plain markdown links with a one-line "read when…" hook each**; the onboarding doc's (§8) is
"read when adding a doc, skill or rule". Guiding reference for leanness:
https://www.aihero.dev/a-complete-guide-to-agents-md

Never reference docs with `@import` syntax: some agents load `@` imports at launch, recursively,
which would silently defeat progressive disclosure (see the Claude row in
[agent-matrix.md](agent-matrix.md)). Only `@`-prefixed paths are imports — plain paths and
markdown links never import; to mention an `@path` literally, wrap it in backticks.

## 2. CLAUDE.md — only when needed

Claude Code v2.1.277+ reads AGENTS.md itself (root and `.claude/AGENTS.md` at start, a
subdirectory's when it opens a file there), so the default is **no CLAUDE.md**. Any `CLAUDE.md`,
`.claude/CLAUDE.md` or `CLAUDE.local.md` in the working directory or above makes Claude read those
**instead** — every AGENTS.md, nested ones included (`~/.claude/CLAUDE.md` and `.claude/rules/` load
alongside either). Keep or create a CLAUDE.md holding `@AGENTS.md` only when genuinely Claude-only
instructions must live below the import (official pattern — preserve them there instead of
force-moving), some sessions cannot load AGENTS.md (Claude Code < 2.1.281 on Bedrock, Vertex AI, a
gateway or with telemetry off, the built-in `agents-md` plugin (`cc-plugin-agents-md@builtin` from
v2.1.285) disabled, **Project instructions** set to `claude-md`), or a CLAUDE.md above the repo
stays and would shadow AGENTS.md; the import never loads AGENTS.md twice. A root CLAUDE.md kept for
any of these reasons shadows nested AGENTS.md files too, so every nested entry file then keeps its
own `@AGENTS.md` pointer. A CLAUDE.md that only says in words to read AGENTS.md becomes the import
or is deleted. A CLAUDE.md→AGENTS.md symlink also works but needs Developer Mode on Windows and
forbids Claude-specific additions. `CLAUDE.local.md` is gitignored (per matrix) yet still shadows
AGENTS.md: the onboarding doc (§8) tells developers to open theirs with `@AGENTS.md`, or to set
**Project instructions** to `claude-md-and-agents-md`.

## 3. Other agents' entry files — detect and convert only

GEMINI.md, `.github/copilot-instructions.md`, `.cursorrules`, `.cursor/rules`, …: convert files
already present in the repo into pointers to AGENTS.md using that agent's include syntax, or
duplicated content where includes are unsupported (per matrix). Never scaffold an entry file for
an agent with no traces in the repo.

## 4. Governing docs

New agent-facing docs default to `.agents/docs/`; the location is always confirmed with the user.
Content-driven — a doc exists only when content exists for it (blocks extracted from entry files,
or relocated later via `/memory-doctor`). During extraction, propose a standard taxonomy as
candidate homes (architecture, conventions, testing, workflow, …) but **never create an empty
stub**. Existing docs elsewhere (`docs/architecture.md`, `CONTRIBUTING.md`, …) are never moved
silently: ask, showing all options — reference in place / consolidate into `.agents/docs/` — with
a recommendation; referencing in place is the usual one, progressive disclosure does not care
about the path.

## 5. Skills

Canonical dirs at `.agents/skills/<name>/`, plus committed **relative symlinks, one per skill**
(per-skill choice; Claude-only skills can coexist):

- `.claude/skills/<name>` → always (Claude carve-out).
- Other agents' project-level skills dirs → only for detected agents, per matrix; agents that
  read `.agents/skills` natively need no link.
- Existing real skill dirs under `.claude/skills/` move to `.agents/skills/` and are replaced by
  symlinks. Symlinks pointing **outside** the repo (personal installs, e.g. into `~/.agents`) are
  left alone and merely reported.

The Windows symlink caveat is documented once, in the onboarding doc (§8).

## 6. .gitignore

Agent-neutral baseline (`.agents/plans/**`) plus per-agent artifact entries from the matrix —
Claude's always (carve-out), other agents' only when detected. Always presented as a diff for
approval.

## 7. Planning directory

`.agents/plans/`, gitignored, with AGENTS.md stating the convention so every teammate's agent
saves plans to the same place. Converged = gitignore entry + AGENTS.md convention line, **not**
directory existence: an empty gitignored dir never reaches teammates' clones, so create the dir
opportunistically when missing.

## 8. Team onboarding doc

In the governing-docs dir: the layout explained; hookup recipes for the agents wired so far
(accumulated from the skill's runtime research); a generic recipe for any other agent — point it
at AGENTS.md via its entry-file mechanism, or re-run `/agentify-project` to research and wire it —
which keeps detect-only from becoming a chicken-and-egg trap for agents with no repo traces yet;
the `CLAUDE.local.md` shadowing hazard and its two remedies (§2); the Windows symlink caveat (git
`core.symlinks` + Developer Mode); and the hook test — after a slimming, give a fresh session a
task that needs one extracted doc and check it opens it; a miss means a weak hook, fixed via
`/self-improve`.

## 9. README pointer

A two-line section in README.md linking to the onboarding/layout doc, so humans who never open
hidden dirs can discover the structure.

## Claude-only variant

A team may deliberately stay Claude-only; the selected areas then apply within that layout: the
entry file in use (AGENTS.md or CLAUDE.md) stays the canonical index (same slimming rules and
plain-link references), the skills area is not applicable (real dirs stay under `.claude/skills/`),
the planning dir defaults to `.claude/plans/`, and doc locations are confirmed with the user with a
Claude-conventional default (e.g. `docs/` or `.claude/docs/`).
