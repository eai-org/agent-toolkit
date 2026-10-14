---
name: memory-doctor
description: Drain the agent's project memory block by block, relocating each entry into a home the user controls or archiving it.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "1.8"
---

# Memory doctor

Agent-memory is an unseen side-channel into every session's context window: facts accumulate there,
often by accident, that the user never reviews and cannot govern. This skill drains it. Technically
**nothing** should live in project memory — durable guidance belongs in homes the user controls
(project docs, project skills/rules, user-level skills/rules), and the rest is garbage. Block by
block, move each entry to its proper home or archive it, until memory trends toward empty and the
user — not the memory store — decides what reaches the context window.

## Golden rule

**The skill guesses and recommends; the user decides.** Every verdict, scope, form, and target is a
*proposal* the user confirms or flips. When unsure, ask. Nothing is moved, deleted, or written
without explicit per-item approval. For every block the user gets the whole fixed menu —
relocate/merge, archive (recoverable), keep, or a custom action they type — never just the
recommended verdict, never a pruned subset.

## Locate the memory

Find the memory store for the current project. Its location is agent-specific — other agents store
it elsewhere, or not at all. **Claude Code** example: the store sits under
`${CLAUDE_CONFIG_DIR:-~/.claude}/projects/`, the `<root>` below. First check the settings for a
relocated memory dir (`autoMemoryDirectory` in any scope), then the `CLAUDE_CODE_PROJECT_DIR_NAME`
env var, which names the `<slug>` directory outright but is honored only with `CLAUDE_CONFIG_DIR`
set. Otherwise slugify the main worktree root — the parent of
`git rev-parse --path-format=absolute --git-common-dir` (not `--show-toplevel`, which in a linked
worktree returns the worktree's own path), else the cwd — by replacing every non-alphanumeric
character with `-` (e.g. `/Users/me/my.app` → `-Users-me-my-app`), then look for
`<root>/<slug>/memory/MEMORY.md`; no exact match → list `<root>` and pick the entry matching the
repo root. If that fails too, or the user runs a different agent, **ask the user for the memory
path**. Only discovery is agent-specific; everything below is agent-agnostic.

**Block** = the smallest self-contained memory unit — typically one memory file plus its `MEMORY.md`
index line, generally one fact each, though a store may group differently. If the memory is a single
flat file with no index, treat each section as a block.

## Flow

1. **Scan (read-only).** Read every block. To judge staleness you may read or grep project files,
   git, and governing docs — but make **no** mutation in this phase.
2. **Triage table.** Present all blocks as ONE narrow overview table that renders as a table, not a
   wrapped list: `# | block | content (≤1 line) | verdict | why + target`. Every cell is a summary:
   the `content` cell one line, the `why + target` cell folding justification, duplicate/garbage
   evidence, and relocate scope/form/path. Full detail for a block waits for its question (step 3).
   The table numbers each block (1…N); refer to a block by that number, in order, and never re-list
   block numbers out of sequence in surrounding prose. The table ends the turn; step 3 begins the
   next — a same-turn question buries the table behind the prompt.
3. **Decide, one question per block, in strict index order (1 → last).** Walk blocks by their table
   index — **never group, batch, or reorder blocks**, even when adjacent ones share a verdict; ask
   about exactly one block per prompt. For each, lead with the detail the table only summarized — a
   verbatim content excerpt plus the full justification — so the user can judge, then present its
   recommended verdict as the default, then the **same fixed menu every time** regardless of that
   verdict — relocate/merge, archive (recoverable), keep, or other (the user types a custom action).
   Never drop an option because it seems not to apply; the user must never have to type a standard
   option by hand. Record each confirmed choice and move straight to the next block — **act on
   nothing yet**; never skip a block or record a choice without its own explicit confirmation.
   Word each question via `explain-in-simple-language` when available.
4. **Execute, once every block is decided.** Apply the recorded actions in index order, honoring the
   Safety rules below (relocate-before-delete, honest index). Doing all the work in one pass —
   never interleaved with the questions — keeps the decision phase a fast, uninterrupted Q&A. Step
   3 confirmed verdict, scope, form and path; each relocate or merge still gets self-improve's diff
   approval here, so expect one short approval per write. Archive moves need no further approval.

## Verdicts

- **Duplicate** — already covered by an existing project/user skill, doc, or rule. **Cite the
  specific file** (ideally line). Prefer a **merge** — fold any wording the block states better into
  the existing home — over a blind delete.
- **Garbage** — delete-worthy: **stale** (cites code/files that no longer exist — *verify* by
  reading/grepping, never assume), **re-derivable** (restates what the code, git, or a governing doc
  already makes obvious), or a **one-off** that never generalized. Never garbage on suspicion; the
  skill must have verified, and the user still confirms.
- **Relocate** — genuine durable guidance with no current home. Route by scope × form (below).
- **Keep** — real and durable, but no good home yet and not worth manufacturing one. Log it in the
  summary and **leave the block untouched** — do not annotate it as "reviewed"; that is just more
  context-window noise.

## Routing for relocate (scope × form)

Both axes are proposals the user confirms or flips.

- **Scope** — *"would this be true or wanted in a different project too?"* Yes → **user-level**
  (the agent's own config home). No → **project-level** (a doc in the repo, or the repo's
  project-scoped skill/rule config). For user-level, **do not** assume reusable config lives in any
  particular managed repo; if it does, the user redirects on confirmation.
- **Form** — short standing behavioral constraint → **rule**; multi-step procedure with a trigger →
  **skill**; reference knowledge/design/context read when relevant but not an instruction → **doc**.

**Target path.** Each relocate or merge proposal names the concrete file: an existing doc, skill or
rule to merge into, or a new file in the home the repo's governing docs name (the docs index,
onboarding or doc-placement doc); without one, a skill or rule falls back to the agent's project
config dirs (e.g. `.claude/skills`, `.claude/rules`), a doc to a path the user names. User-level
homes are the agent's own config dirs (e.g. `~/.claude/skills`, `~/.claude/rules`).

Do each relocate or merge through [self-improve](../self-improve/SKILL.md) in its driven mode: hand
it the block's content plus the confirmed scope, form and path; it drafts and applies the edit
(routing the write through the matching compaction skill), and locates the home itself only for a
target the user left open. This skill owns discovery, enumeration, classification and the archive
path; self-improve owns the write.

## Safety

Memory files live outside the project repo and are **not** in git, so a delete is irreversible.

- **Relocate-before-delete.** A block's content leaves memory only once it has landed in a confirmed
  home (relocate/merge applied) **or** the user explicitly OKs it as worthless. Never archive or
  delete the source before the destination edit is confirmed-applied.
- **Archive, don't `rm`.** Worthless blocks are *moved* to `memory/.archive/`, not deleted — an
  archive folder costs nothing in context and stays recoverable.
- **Keep the index honest.** Update the `MEMORY.md` index line in the **same step** as any block
  removal or relocation: never orphan a file, never dangle a pointer to a moved or archived one.

## Close

Print an **ephemeral chat summary** — no report file (that would just be new uncontrolled state).
Include counts plus each block's disposition (relocated → where, merged, archived, kept, skipped),
and list kept blocks with each one's "no home because…" reason. The real deliverables are the
cleaned memory and the archive folder.
