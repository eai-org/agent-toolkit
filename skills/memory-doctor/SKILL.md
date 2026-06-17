---
name: memory-doctor
description: Audit the current project's agent-memory and, block by block, relocate each entry into a user-controlled home (project doc/skill/rule or user-level skill/rule) or archive it — draining memory so nothing uncontrolled accumulates in the agent's context. Manual-only.
disable-model-invocation: true
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.0"
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
without explicit per-item approval. For every block the user gets the whole menu — relocate, delete,
keep — never just the recommended verdict.

## Locate the memory

Find the memory store for the current project. Its location is agent-specific — other agents store
it elsewhere, or not at all. **Claude Code** example: slugify the project's absolute
working-directory path by replacing each `/` with `-` and prefixing one `-`, then look for
`~/.claude/projects/<slug>/memory/MEMORY.md` (e.g. cwd `/Users/me/app` → `-Users-me-app`). If that
path is absent, or the user runs a different agent, **ask the user for the memory path**. Only
discovery is agent-specific; everything below is agent-agnostic.

**Block** = the smallest self-contained memory unit — typically one memory file plus its `MEMORY.md`
index line, generally one fact each, though a store may group differently. If the memory is a single
flat file with no index, treat each section as a block.

## Flow

1. **Scan (read-only).** Read every block. To judge staleness you may read or grep project files,
   git, and governing docs — but make **no** mutation in this phase.
2. **Triage table.** Present all blocks in one table so the user sees the whole memory at once:
   `block | content (verbatim excerpt or summary, ≤10 lines) | verdict | justification | evidence
   (duplicate/garbage) | scope/form/path (relocate)`. Truncate long blocks, but show enough that the
   user can judge each without opening the file.
3. **Execute, block by block in strict index order (1 → last).** Walk blocks by their table index;
   **never group or reorder by verdict** (don't do "all duplicates first, relocates next"). For each
   block, present its recommended verdict *and* the full option menu — relocate/merge to the
   recommended home, delete (archive), keep as-is, plus any block-specific alternative — then apply
   only the user's chosen action before moving to the next. The verdict is only a default; never
   skip a block or act on one without explicit per-block confirmation. If you batch decisions into
   one prompt, it must cover **every** block as contiguous index ranges (e.g. 1-4, then 5-8) — never
   a verdict-grouped subset.

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

If using Claude Code: user-level config lives in `~/.claude/skills` and `~/.claude/rules`,
project-level in the repo's `.claude/skills` and `.claude/rules`.

**Do the relocation through [self-improve](../self-improve/SKILL.md)** — it finds the home, drafts
the least-text edit, and applies it (routing skill edits through compact-skill-creator). This skill
owns discovery, enumeration, classification, and the archive/delete path; self-improve owns writing
the content into its home.

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
