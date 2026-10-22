---
name: agentify-project
description: Make a project agent-ready by converging it toward a canonical agent-neutral structure. Re-runnable, and doubles as an audit.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "0.5"
---

# Agentify project

Converge a project — greenfield or half-way-there — toward the canonical agent-neutral structure
specified in [references/target-structure.md](references/target-structure.md) (read it before the
audit), so a team of developers using different agents shares one lean, progressively disclosed
setup. Re-running converges further and reports drift.

Invocation: `/agentify-project [audit] [path]`

- `audit` — run step 1 only, print the findings and what a full run would change, modify nothing;
  the periodic drift check.
- `path` — target a subdirectory instead of the repo root (see Monorepos).

## Principles

- **Ask, don't enforce**: prefer asking — all options shown, one recommended — over enforcing a
  choice, except for obvious easy wins (e.g. clear progressive-disclosure moves). Questions
  answerable from the codebase go to the codebase.
- One approval gate per destructive/bulk change; show diffs or proposals before applying; nothing
  happens behind the user's back. Never commit — suggest reviewing the diff and leave committing
  to the user.
- Generic: behavior is driven by [references/agent-matrix.md](references/agent-matrix.md) — read
  it whenever agent detection or an agent's specifics are needed. One documented exception, the
  **Claude carve-out**: a team with no Claude users at all is rare, so Claude wiring (the
  `.claude/skills/` links, the Claude gitignore entries) is applied unconditionally, never
  detection-gated. A CLAUDE.md pointer is not part of it: current Claude Code reads AGENTS.md
  itself (target-structure §2).

## 1. Audit (read-only)

- Detect each target-structure area's state, and which agents are in use by their traces (matrix).
- Warn — never block — if the git working tree is dirty, so the user can commit first and keep
  the restructure reviewable as an isolated diff.
- Detect nested entry files (monorepo packages).
- Report any `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` in a parent directory of the
  main checkout, except the user-level `~/.claude/CLAUDE.md`: with no CLAUDE.md pointer in the
  repo it makes Claude Code skip AGENTS.md (target-structure §2), so the pointer becomes a menu
  item. The main checkout is the parent of `git rev-parse --path-format=absolute --git-common-dir`,
  not `--show-toplevel`, which in a linked worktree (agents often create one inside the repo, e.g.
  `<repo>/.claude/worktrees/<name>/`) returns the worktree. The main checkout's own root
  `CLAUDE.md`, `.claude/CLAUDE.md` and `CLAUDE.local.md` are the repo's files, never a
  parent-directory CLAUDE.md that stays, and never alone keep or recreate a pointer.
- Diff duplicated entry files (agents without include syntax) against AGENTS.md; divergence
  becomes a re-sync menu item — the one artifact class guaranteed to drift.
- Check every path and link in the entry files and index resolves; a dead one is a menu item (fix
  or drop).
- Detect Claude-only assets (`.claude/commands/`, `.claude/agents/`, `.claude/rules/`): report,
  leave. Report unscoped rules files as always-on, and flag `.claude/rules/` content as candidate
  governing-doc material (path-scoped rules are a Claude-specific disclosure mechanism); legacy
  commands may get a one-off note that they could become skills — the conversion itself is out of
  scope.
- Record always-on line counts — entry files plus any rules file without a path scope (they load
  every session): menu annotations now, coarse before-figure for `/context-checkup` later.

Done when every target-structure area has a detected state and every agent trace found is
accounted for.

## 2. Menu

Multi-select over the applicable change areas only — entry-file indirection, AGENTS.md slimming
into docs, skills relocation + symlinks, gitignore hygiene, planning dir, onboarding doc, README
pointer — each annotated with audit findings (e.g. "CLAUDE.md, 180 lines, no AGENTS.md →
indirection + slimming"). **"All" is the first and recommended option.** Report already-converged
areas ✓ and omit them from the choices. Every area is independently skippable: a team may
deliberately stay Claude-only (no multi-agent support) — then apply the selected areas within the
Claude-only variant in target-structure.md.

## 3. Execute — live, step by step

Apply each accepted area immediately, behind its approval gate — no migration-plan artifact: the
moves are mostly mechanical, and re-running converges. Suggested order: entry files →
slimming/docs → skills → gitignore → extras.

**Entry files.** Invariant covering every starting state: the content of **all** existing entry
files — any agent's, including a divergent CLAUDE.md + AGENTS.md pair — feeds the slimming
mapping; AGENTS.md ends canonical; every detected third-party entry file ends as a pointer (or
duplicated content, per matrix); CLAUDE.md ends absent or as a pointer, per target-structure §2.
Common case (CLAUDE.md exists, no AGENTS.md): rename it to AGENTS.md with a plain filesystem move
(no `git mv`; git detects the rename at commit time) and recreate CLAUDE.md as `@AGENTS.md` only
when §2 calls for one (a genuinely Claude-specific remainder, sessions that cannot load AGENTS.md,
or a parent-directory CLAUDE.md that stays); otherwise it stays deleted. Run from a linked
worktree: a tracked entry file the branch renames or replaces gets a report note that worktree
sessions keep loading the main checkout's copy until the branch reaches it; an untracked one (the
gitignored `CLAUDE.local.md`) gets target-structure §2's `CLAUDE.local.md` remedy, with no such
note. AGENTS.md-only and third-party-only repos: same invariant — pointers only for the third-party
agents detected, never a bare CLAUDE.md; seed AGENTS.md from whatever entry-file content exists.
Greenfield (no entry file of any agent): minimal seed from cheap reconnaissance (README, package
manifest / build files) — one-liner, **verified** build/test/run commands, planning-dir
convention; deep doc generation is out of scope, the structure grows later via `/self-improve` and
`/memory-doctor`.

**Slimming (mapping-first).** Draft one full mapping: each block → stays / moves to existing doc
X / new doc Y, applying the keep-vs-extract test (target-structure §1); where a block's relevance
is verifiable from the codebase, check the code instead of asking. Present the mapping with
obvious calls pre-decided; walk **only doubtful blocks** as individual questions, each with a
recommendation, worded via `explain-in-simple-language` when available; one approval gate before
any edit. Offer a compaction pass on blocks that stay; write extracted docs compact from birth —
via `compact-docs-writer` when available, else inline with its core principle (least text, zero
information loss). Each extracted doc gets a plain-link index entry in AGENTS.md with its "read
when…" hook.

**Skills.** Move real dirs, create relative symlinks (committed), per matrix; leave
foreign/personal links untouched and report them.

**Gitignore.** Show the proposed block as a diff; apply on approval.

**Extras.** Planning dir + AGENTS.md convention line; onboarding doc, indexed with its hook
(target-structure §1); README pointer.

Done when every selected area is applied or explicitly skipped by the user.

## 4. Verify (mechanical)

Every AGENTS.md reference resolves; symlinks point at real dirs; `git check-ignore` confirms each
ignore entry; no `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` shadows AGENTS.md (each
absent, or an `@AGENTS.md` pointer — a tracked file the branch replaces in the main checkout is
not reported; a real file above the main checkout or an untracked shadowing file still is) and,
when the root keeps a CLAUDE.md, every nested AGENTS.md has its pointer too (target-structure §2);
duplicated entry files match AGENTS.md. Close with a short converged-state report of what
changed; after a slimming, state the hook test: give a fresh session a task that needs one
extracted doc and check it opens it; a miss means a weak "read when…" hook, fixed via
`/self-improve` when available (gated as in §5). Point at the onboarding doc's copy
(target-structure §8) only when that doc exists at the end of the run.

## 5. Close

Suggest, each only when available (look in the agent's skills and plugin dirs, as manual-only
skills are missing from the in-session list) and applicable, with this skill's own namespace prefix
if any — skip silently otherwise:

- `/memory-doctor` — when the agent accumulates project memory (e.g. auto memory) — to relocate
  saved lessons into the new docs structure and share them with the team; it no-ops harmlessly on
  empty memory, so no content check is needed.
- `/context-checkup` — measure what now auto-loads, with the audit's always-on line counts as
  the coarse before-figure.

## Monorepos

Full treatment targets the repo root. Nested entry files are offered only the cheap mechanical
indirection (nested CLAUDE.md → nested AGENTS.md; pointer per target-structure §2 — always kept
while the root has a CLAUDE.md); defer nested slimming to a re-run with that subdirectory as the
`path` argument. A `path` run covers that directory's entry-file and slimming areas only; skills,
gitignore, planning dir, onboarding doc and README pointer stay root-level.
