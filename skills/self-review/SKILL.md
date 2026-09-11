---
name: self-review
description: Self-review a changeset until merge-ready — a fresh-context reviewer checks it as a maintainer would, the author answers every finding, and a compact report for the PR proves the review happened.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "0.10"
---

# Self-review

Make a changeset merge-ready before submission — no regressions, sound code, the project's
conventions respected — and prove it was scrutinized: a fresh-context reviewer hunts for what
would block the merge, the author answers every finding, and a compact report — scannable by a
maintainer in seconds — records the outcome. The report is the review record only; the change's
what/why belongs to the PR description (e.g. via /handover), never here.

Only for a changeset you authored. The fresh-context reviewer exists to escape authoring
blindness, so someone else's PR has nothing to escape and belongs to `maintainer-review`.

## Resolve the changeset

1. Resolve source and target. No input → current branch against the auto-detected target: the
   default branch of the `upstream` remote when one exists (fork workflow), else of `origin` —
   via `git ls-remote --symref <remote> HEAD`, never the often-absent local
   `refs/remotes/<remote>/HEAD`; that failing (e.g. offline), the sole existing candidate among
   `main`, `master`, `develop`/`development` (preferring `upstream`'s remote-tracking ref, then
   `origin`'s, then the local branch) — still ambiguous or none → ask. Explicit branches in the
   invocation win; a detached HEAD → ask which branch is under review. State the chosen target.
2. The reviewed state is the source as it stands — working tree when checked out, else tip.
   Uncommitted work is reviewed, not blocked, once the author sorts it: modified tracked files
   are part of the change or deliberate local-only tweaks (build config, data paths), the latter
   excluded from the diff (pathspec) and named in a procedural caveat — exclusion drops the whole
   path, so a tweak atop a changed file the author stashes first; untracked files likewise, and
   since the diff can't see them, those that belong the author `git add`s first — a forgotten one
   ships unreviewed later. The reports this skill writes need no sorting and are always excluded.
   Nothing beyond the tip reviewed → **pinned** to its SHA; otherwise **unpinned** — reviewed,
   but with no SHA for a maintainer to check the pushed head against, until stamped. Pinned is
   preferable, so suggest committing first when the work is ready for it — never insist, the
   stamp closes the gap later.
3. `git fetch` the target's remote (local-only target → nothing to fetch; a failed fetch → say
   so and ask rather than diff stale refs), then diff from the merge base `<base>` of target and
   source: `git diff <base>` for the working tree, `git diff <base> <source>` for a tip. No merge
   base → usually a shallow clone or wrong target: deepen (`git fetch --unshallow`) and retry,
   else ask — never fall back to diffing against the target itself, which presents its own
   commits as the author's. Empty diff → probably a wrong target (typical: a fork's default
   branch already holding the commits) — say so and ask for the true one; it needs no local
   ref, `git fetch <url> <branch>` works by URL.
4. Assemble the submission metadata as one block, hashed like the diff: the lines `subjects:`,
   `title:`, `body:`, `issues:` in that order, each followed by its value's lines verbatim —
   subjects from `git log --format=%s <base>..<source>`; from the target forge's open PR of source
   into target, its title, description and the issue ids it lists as linked (as the forge shows
   them, sorted, one per line); nothing under a label without a value (e.g. no PR yet) — every
   line LF-terminated, CRLF folded to LF, each value's trailing blank lines dropped.

Done when source branch, target, reviewed state (SHA, or working tree on SHA), the diff's hash
(`git diff … | git hash-object --stdin`) and the metadata's are recorded and the diff is non-empty.

## Project rules file

`.agents/docs/self-review-rules.md`, when the project carries one, adds project-specific rules or
overrides to the review mandate and process (extra focus areas, round cap, full rounds only, report
handling, a pinned review required — modified tracked files then block every round, fixes committed
before the next) — never to the Boundaries below. Absent → skip silently. Either way, the report
states whether it was found and applied.

## Review

A report already present → Stamp (below) the latest first.

Load and follow [fresh-eyes-review](../fresh-eyes-review/SKILL.md) on the reviewed state — whole
in a changeset's first round, narrowed per Rounds below in any later one — inputs all explicit, so
it runs without its confirmation step — with:

- an intent statement — one or two sentences distilled from the task's ticket or requirements
  when the planning home holds them, never the document itself (it carries the author rationale
  excluded below), else derived from the branch name and commit subjects; derivation yielding
  noise (`wip` commits, opaque names) → ask the author for a one-liner, proposing a draft.
  Either way, state the intent used — the author must see what the change is judged against;
- excluded paths: the planning home and the reports — author rationale and past dispositions must
  never reach the reviewer. Planning files the changeset itself touches ship in the PR, so they
  are reviewed like any other change; the reports stay excluded always;
- the mandate framed as a maintainer's merge gate — would anything here block the merge? — and
  extended by: the project's own governing docs (contributing, agent instructions, codestyle) run
  as a checklist, not as background reading, against every changed file, the unchanged code the
  change newly relies on, and the submission itself, whose metadata block (step 4) the prompt must
  carry verbatim; and leftovers — debug prints, commented-out code, stray TODOs, accidentally
  committed files;
- the grounded bar: a finding exists only with a nameable concrete failure, violated rule, or
  redundancy — hedged speculation is out, zero findings is a valid outcome;
- an instruction to the reviewer to report back the harness and model it ran on, and whether it
  covered every changed file in its scope — naming any it didn't.

Done when the reviewer has returned its findings — possibly none — its provenance, and its
coverage.

## Disposition walk

Before the first finding, check which planning documents the task has (ticket, requirements,
plan) and read any that exist: recommendations must weigh the full story. These documents still
never reach the reviewer, which sees only the distilled intent (Review above).

One finding at a time, recommending a disposition with a one-line why — the author decides, and
discussing the finding is offered as visibly as the dispositions themselves, never left an implicit
escape hatch. Anything the author says that isn't a disposition is discussion, not a decision:
answer the question, check the code, revise the recommendation, do what they ask with the finding —
then the walk returns to that same finding, still open. Three dispositions close one:

- **fix** — apply it to the working tree now; committing stays the author's move. Submission
  metadata (PR title, description, commit subjects) the agent only drafts — applying it is the
  author's (Boundaries).
- **dismiss** — record the author's reason, pushing once toward one a maintainer can evaluate
  ("the caller already null-checks", not "disagree"); "mirrors the existing pattern" counts only
  once that pattern is verified sound — an unchecked one ratifies its bugs; if the author
  insists, their words go in verbatim.
- **defer** — not fixed and not dismissed but handed onward: a follow-up ticket, a comment on
  another PR, a note the author keeps. Record the destination in one line; drafting the text is
  in scope, filing or posting it is not (Boundaries).

Never drop or soften a finding: every one appears in the report with its disposition. Dispositions
carry forward across rounds: a re-raised finding matching a dismissed or deferred one keeps that
disposition and is not re-walked; one matching a fixed finding means the fix didn't hold — reopen it
and walk it again, except an unapplied metadata draft: pending, not failed. The report lists each
finding once, with its latest disposition.

Done when every finding of the round is dispositioned and diff and metadata re-hashed as in steps
3 and 4.

## Rounds

Anything fixed, or a file left uncovered, → a fresh round on the new state — fixes are new
unreviewed code; a metadata draft earns one only once applied (below). Committing between rounds
stays the author's move (propose a commit message in the repo's style), demanded only where project
rules require a pinned review. The first round reviews the whole changeset; every later one, in
this invocation or a re-run, only the **delta** — what changed since the last reviewed state — and
its reach. The reviewer gets the full current diff as reference, plus:

- the delta hunks — one the walk applied carries the failure it addressed, never its disposition;
  dismissed and deferred findings go unmentioned;
- files the last round reported uncovered, reviewed whole as in a first round;
- the mandate: check each hunk holds and follow its reach — call sites of what changed, mirrored
  sites, the tests and docs covering it, whatever else it judges reached; the rest of the changeset
  was reviewed and stands: no hunting there, though a grounded finding met on the way is reported
  like any other; governing-docs checklist and leftovers hunt over the delta and the uncovered
  files only.

The delta must be exact, else the round runs full, saying why. Exact: the fixes the walk applied —
possibly none — when the diff hash the walk took still matches at round start, or none in the
round a Stamp with **Diff** equal orders; else `git diff <SHA>` (a tip: `<SHA> <source>`), with
step 2's exclusions, when the last reviewed state is a commit `<SHA>` whose merge base with the
target is still `<base>`. Full also whenever the author asks or project rules require it.
Submission metadata whose hash differs from the last round's (none recorded → differs) — a fix the
author applied, a new commit's subject — joins the delta as its re-read text, judged against the
diff it describes; alone, it still earns a round.

Rounds stop when one earns no fresh round — nothing uncovered, nothing fixed (clean, or every new
finding dismissed, deferred or a draft still unapplied), no metadata changed — or at the cap of 3
per invocation, there to bound cost; the author can stop earlier at any point, or explicitly ask
for rounds beyond the cap. Every fix no later round covered — an unapplied draft included — leaves
a "fixes not re-reviewed" caveat in the report naming it.

Done when a stop condition has ended the rounds.

## Report

`<slug>.SELF-REVIEW.md` in the task's planning home, per the project's planning-directory
convention (e.g. `.agents/plans/<slug>/`); reuse the slug of the task's existing artifacts
(ticket, requirements, plan) — none → derive it from context (branch name, the changes); no
planning home resolvable → default to `.agents/plans/<slug>/`, stating the choice rather than
asking. Later rounds update the file this invocation wrote; a re-invocation carries the latest
file's dispositions forward into the next free name — `<slug>.SELF-REVIEW-2.md`, `-3`, … —
holding only its own rounds, numbered on from it, never overwriting; a stamp alone edits the
latest in place. The newest is the one to paste into the PR description or a comment. None is for
committing, unless the project rules file says otherwise — either way committing is the author's
move, never the agent's.

Two parts — maintainers drown in AI-generated review walls, so the visible part stays minimal.
Visible, each line its own paragraph (blank lines between, no blockquote): the heading, **Outcome**,
outcome-weakening caveats, **Reviewed**, **By**, verification evidence (e.g. testing performed).
Everything else collapses into `<details>`, in order: **Intent**, **Project rules**, **Diff**,
**Metadata**, procedural caveats, the rounds; the blank line after `</summary>` is required —
without it the markdown inside won't render. Placement, unless project rules explicitly override:
a caveat is visible iff it weakens what **Outcome** claims (fixes not re-reviewed, incomplete
coverage naming the unreviewed files, a same-context fallback), procedural confirmations (e.g.
files confirmed local-only) collapse; any other line is visible iff it records verification
performed or qualifies the outcome — proof-of-process collapses.

Compact above all: one line per finding, fusing location and concrete failure; the full prose stays
in the session. The **Reviewed** line always carries the latest round's state (`working tree on
<SHA>`, marked `unpinned`, when not a commit; once stamped, the new SHA with `stamped from <that
state>`) and diffstat; **Diff** and **Metadata** their full hashes (never a later fix's), for the
Stamp; history lives in the round headings, each naming the state it reviewed and, after the
first, its scope — full with its reason.
Provenance exactly as the environment reports it, `unknown` when it doesn't — never guessed or
recalled; the reviewer's model, when it differs from the session's, appended to the **By** line as
`review by <model>`; skill version from this file's frontmatter, date = today.

```markdown
# Self-review — my-feature → main

**Outcome** 4 findings — 2 fixed, 1 deferred, 1 dismissed — final round clean

**Reviewed** `def5678` (`my-feature` vs `main`, merge-base diff — 12 files, +340 −120)

**By** <harness>, <model> — self-review v<version>, <date>

<details>
<summary>Review details (2 rounds)</summary>

**Intent** <the intent statement the review ran against>

**Project rules** `.agents/docs/self-review-rules.md` not present

**Diff** `9f2c1e0b7d3a4c5e6f718293a4b5c6d7e8f90123`

**Metadata** `4d5e6f718293a4b5c6d7e8f901239f2c1e0b7d3a`

## Round 1 — `abc1234`, 4 findings

1. `src/foo.c:142` — null deref when the timer expires mid-update → **fixed**
2. `db/updates/xyz.sql:3` — DELETE misses linked_id rows, orphans on re-run → **fixed**
3. `src/bar.c:210` — retry loop has no backoff, hammers the API during an outage → **deferred**:
   predates this change, author files it as a follow-up ticket
4. `src/foo.c:97` — guard duplicates the check 4 lines up → **dismissed**: mirrors the pattern in
   this file, checked sound at :61 and :88; refactor out of scope

## Round 2 — `def5678`, round 1 fixes, clean

</details>
```

Done when the report holds the outcome line, intent, changeset refs with diffstat, diff and
metadata hashes, provenance with skill version and date, rules-file status, and every round with
its reviewed state, scope (after the first) and dispositioned findings — each on its mandated side
of the split.

## Stamp

Step 3's hash equal to the report's **Diff** → content unchanged (after committing the reviewed
work, an amend, a rebase leaving the diff byte-identical): no round on it; **Reviewed** line set to
the current state — a tip → `stamped from <previous state>` replacing `unpinned` — then, given
changed metadata (Rounds) or a caveat naming a file uncovered, Review onward as a later round on
those alone, else Wrap up. Different → say so, Review onward as a later round (Rounds). Done when
the report carries the current state or Review has started.

## Wrap up

Print: the report's project-relative path, with the instruction to paste its content into the PR
description or a comment; a warning not to commit the report — a later `git add .` drags it into
the PR — unless the project rules file says otherwise; a reminder to run the project's usual
checks (build, lint, tests) before pushing — this skill never runs them; and that the pushed head
must match the reported SHA: unpinned → commit, then re-invoke to stamp; any later commit or
metadata edit → the same re-invocation: a stamp when the content held, its changed metadata
reviewed alone, else a re-run. Done when all four are printed.

## Boundaries

- Files written: the report, and the fixes the author approved during the walk — nothing else.
- Read-only git plus `git fetch`; no commit, push, or PR operation — publishing is the author's.
