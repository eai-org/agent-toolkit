---
name: create-manual-test-instructions
description: Turn a ticket, requirements document or code change (branch, PR, commit range, diff) into a concise QA manual-test file a non-author can follow. Invoke manually only.
context: fork
license: MIT
metadata:
  version: "1.9"
---

# Create manual test instructions

## Resolve the input

- **Ticket or requirements document** (file or pasted text) — the only source: the checks follow
  it, and no code change is looked up.
- **Code change** — a branch, PR URL, commit range, pasted diff or patch file, or nothing (the
  current branch). A commit range is diffed between its own ends. A branch or PR: `git fetch` the
  remotes, then diff from the merge base `<base>` with the target — a PR's base from its
  metadata, else the default branch of the `upstream` remote when one exists, else of `origin`,
  via `git ls-remote --symref <remote> HEAD`; that failing, the sole existing candidate among
  `main`, `master`, `develop`/`development`, preferring `upstream`'s remote-tracking ref, then
  `origin`'s, then the local branch. `git diff <base> <source>` for a tip; a checked-out source
  is reviewed as its working tree: `git diff <base>` plus the untracked files
  (`git ls-files --others --exclude-standard`), read whole. Read the commit subjects and the PR
  title and description too. Then resolve the task's planning home — its `<id>-<slug>/` directory
  (no ticket → no id) or flat `<id>-<slug>.*` files in the project's planning directory, id and
  slug from the branch name or PR — and read the ticket and requirements there when present for
  the intent, the "before" and the edge cases; the checks still follow the code, a Reproduction
  part's steps aside (What to verify). No merge base → `git fetch --unshallow` and retry. Running
  forked, you can't ask mid-run: an ambiguous target, a failed fetch, still no merge base or an
  empty diff → write nothing and say in the final message what to pass on the next run; never
  guess a target.

Where needed for accurate navigation, also read the code the input cites and the design frames or
screenshots it links when they are on disk.

## Write the file

Next to an input ticket or requirements file, naming it by replacing `.REQUIREMENTS` or `.TICKET`
with `.MANUAL-TEST` (`FOO.REQUIREMENTS.md` → `FOO.MANUAL-TEST.md`); neither convention → append
`.MANUAL-TEST` before `.md`. A code change with a planning home → `<id>-<slug>.MANUAL-TEST.md`
beside the task's other artifacts. Otherwise (pasted text, a diff or patch file, a branch without
artifacts) follow the project's/user's convention for where plans live (default: `.agents/plans/`)
and write `<id>-<slug>/<id>-<slug>.MANUAL-TEST.md` there, id and slug from the branch name or PR,
else a kebab-case slug from the content. An existing manual-test file of that name is replaced;
the final message says so. Flag any guessed location or slug in the final message for the user to
verify.

The file must be followable by someone **unfamiliar with the ticket** — short but complete. Four
parts:

1. **What changed** — 1–2 sentences: the feature and the user-visible difference.
2. **How to get there** — concrete navigation to the affected area (entry point, page/screen name,
   any prerequisite state).
3. **Before vs after** — how the area behaved before, how it should behave now.
4. **What to verify** — checklist of behaviors to confirm, including edge cases (empty values,
   multiple items, boundaries) where relevant. A requirements document's Reproduction part, in the
   input or read for a code change, gives the first check, a regression check: its steps, passed
   when the expected behaviour it records shows. A ticket's own reproduction field isn't that part.
   A behaviour resting on an Open question of the input goes under a closing **Not settled yet**
   line, never as a plain check: on a non-blocking question, with its tentative answer; on a
   blocking one, listed as undecided, naming who decides when the input names them, with no
   expected value — never invented. Each point where a code change differs from its ticket —
   built but never asked for, or asked for but not built — goes under a closing
   **Differs from the ticket** line, with nothing invented for the missing side.

A change with nothing a person can test by hand (a refactor, a dependency bump, a backend change
with no visible effect) still gets the file: part 1 says why, the other parts stay empty.

Before writing, actually invoke [explain-in-simple-language](../explain-in-simple-language/SKILL.md)
and follow it — reciting its rules from memory does not count. Not installed: plain words, one idea
per sentence, and nothing named only by a stand-in the reader hasn't seen.

Do not modify any source files; the only file you write is the manual-test document.

When done, state the manual-test file's **project-relative path** and, for a branch or PR, the
target and the source state (tip or working tree) you diffed.
