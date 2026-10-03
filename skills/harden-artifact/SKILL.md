---
name: harden-artifact
description: Harden a REQUIREMENTS or PLAN document before the next phase picks it up — checked against its ticket, the code and related tickets, proven mistakes fixed in place.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "0.1"
---

# Harden artifact

Make a `.REQUIREMENTS.md` or `.PLAN.md` — the **artifact** — safe to hand to the next phase:
every deviation from its ticket deliberate, explained and correct; every claim true; nothing
blocking the session that picks it up. A fresh-context reviewer hunts, the session challenges
each finding, and only what survives changes the artifact — which **must never end worse than it
started**.

A session that wrote the artifact cannot judge findings on it: say so and propose a fresh session
before continuing.

## Resolve the sources

- **Artifact** — the file the invocation names; ambiguous or neither kind → ask. A plan — the
  artifact or one of the same base — with a ticked task is already being built, past where
  hardening belongs → say so and ask before going on.
- **Ticket** — the document the artifact was refined from, found by file name: the artifact's
  suffix replaced by `.TICKET` (`FOO.PLAN.md` → `FOO.TICKET.md`), or, when the stem names another
  source, that file (`FOO.PR-REVIEW.REQUIREMENTS.md` → `FOO.PR-REVIEW.md`). A source with
  decisions recorded beside it (a PR review's `.ANSWERS.md`) is read with them: only what they
  accept is the ticket — the rest is out of scope, never a deviation, never recorded in the
  artifact. Ambiguous → ask; no file → ask whether the ticket lives elsewhere (a tracker id,
  pasted text) before treating it as none.
  None (e.g. requirements brainstormed from an idea) → say so: a plan is compared with its
  upstream instead; with neither, the review runs without the Deviations lens.
- **Upstream** (a plan only) — its name with `.PLAN` replaced by `.REQUIREMENTS`, when that
  exists.
- **Related tickets** — those on disk: the ticket's `## Ticket set`, its parent, its siblings,
  later ones that build on this work included.
- **Repos** — every repo the feature spans, as named by the ticket, the artifact and the project's
  governing docs: where it is built, the other side of each integration it relies on, and whatever
  will consume what it delivers (a backend ticket's frontend, a library's apps, an API's other
  clients, the readers of a changed table). Any that can't be located → one batched ask for
  their paths, autoaccept or not; the user may skip one.

Done when the artifact, the ticket or its absence, and each repo's path or skip are settled.

## Review

Load and follow [fresh-eyes-review](../fresh-eyes-review/SKILL.md) — inputs all explicit, so it
runs without its confirmation step — with the whole artifact as the changeset, one sentence of
intent (the ticket's title — without a ticket, the artifact's own summary — and the phase the
artifact feeds), the sources above (skipped repos named as unavailable), and this mandate in
place of its default:

- **Deviations.** List every difference between artifact and ticket (for a ticketless plan, its
  upstream) in what must be true when the work is done — dropped, added, changed; rewording and
  merged duplicates are not differences, nor is a plan's "how". Each needs a written reason,
  anywhere in the artifact or its upstream: none → a finding. A reason is itself a claim.
- **Claims.** Every decision and factual statement is a claim to test, never accepted because it
  is written. Probe each source class:
  - code — every repo, both sides of each integration, searching for the concept and never only
    the spot the artifact names;
  - related tickets — on disk first; the tracker, read-only, for a specific doubt;
  - designs the ticket references;
  - other docs in the ticket's directory;
  - branches and PRs the tickets link.
- **Future fit.** Does what the artifact delivers fit whoever builds on it next: a later ticket's
  needs, the way the consumer's code already uses analogous things (names, shapes, errors,
  paging)?
- **Readiness.** A fresh session can act on the artifact without the ticket or any conversation;
  no open question blocks the next phase; acceptance criteria are verifiable. Requirements say
  what, never how. A plan's steps are concrete enough to act on, ordered without broken
  intermediate states, and together cover every acceptance criterion.

Grounded bar: every finding names the document the mistake originates in and a citation
verifiable blind — file path + lines + verbatim quote, ticket id + quoted text, or design frame
id; zero findings is a valid outcome. The reviewer also reports, per source class, what it probed
and what it could not reach — unreachable is unchecked, never skipped silently.

Done when the reviewer has returned its findings — possibly none — and its source coverage.

## Challenge

A finding is a conclusion too: before any edit, try to disprove each one. Open its citation and
confirm it exists as quoted **and proves the point** — related evidence is not proof — then hunt
for what contradicts it: a written reason the reviewer missed, a code path elsewhere. Disproved →
dropped, kept for the summary with why. Each survivor is:

- **proven** — ticket text or code settles both that it is a mistake and what the correct text is;
- **suspected** — everything else: not provable, more than one reasonable fix, or a fix that
  changes what gets built beyond what the ticket states (most Future fit findings). A deviation
  with no written reason is suspected too — it may be a decision nobody recorded — unless the
  artifact contradicts itself on it (a requirement its acceptance criteria miss, a plan missing
  what its upstream requires) or the code proves its text wrong.

Done when every finding is dropped, proven or suspected.

## Decide

One finding at a time, recommending a disposition with a one-line why, worded via
`explain-in-simple-language` when available — the user decides:

- **fix** — edit the document the mistake originates in, then the requirements or plan of the same
  base the fix reaches: a plan faithful to requirements that lost an acceptance criterion →
  restore it in the requirements, then align the plan; a requirements fix reaches an existing plan
  of the same base. A plan's `## Tasks` section is never edited: a split plan a fix reached is
  re-split by the Wrap up hand-off, never during the walk.
  A mistake the ticket itself carries is corrected in the documents derived from it, upstream
  first — a ticket file is never edited — and recorded with its reason where each keeps its
  overrides; a deviation the user confirms deliberate gets its reason recorded there too, so no
  later reader re-raises it.
- **dismiss** — record the user's reason for the summary.
- **defer** — handed onward (a question for the requirements owner, a follow-up ticket): record
  the destination in one line; drafting its text is in scope, posting it is not.

**Autoaccept** — the word `autoaccept`, in the invocation or said during the walk, hands the
remaining decisions of this invocation, later rounds included, to the agent: a proven finding is
fixed without asking; a suspected one is still asked.

Every edit, in any mode:

- rests on cited evidence — a ticket quote, a code location — or the user's explicit decision;
- never changes a decision documented as deliberate on the reviewer's or the session's opinion
  alone — ask;
- in doubt, leaves the text untouched and asks;
- reads as the author's own text, with no trace of the review;
- has its replaced text kept for the summary — planning files are often untracked, so no diff
  will show it.

Done when every surviving finding has a disposition.

## Rounds

Any edit earns a fresh round: a new reviewer on the whole artifact with the same prompt, told
nothing of earlier findings or decisions. A re-raised finding matching a dropped, dismissed or
deferred one keeps that outcome unless it brings evidence the earlier one lacked. Rounds stop when
one leads to no edit, or at 3 per invocation; the user may stop earlier or ask for more.

Done when a stop condition has ended the rounds.

## Wrap up

Print — no file is written; what a later reader needs lives in the artifact:

- whether the artifact is ready for the next phase, and what blocks it if not (a deferred finding,
  an unanswered ask);
- **Fixed** — each with the text before and after, and its evidence;
- **Dropped in challenge**, **Dismissed**, **Deferred** — each with its reason or destination, a
  deferred one also with its drafted text;
- sources left unchecked, with the claims resting on them;
- edits no later round covered;
- other documents derived from an edited one (e.g. manual test instructions, a split plan's
  tasks), as possibly stale.

Fixed findings sharing a cause that a governing skill or doc covers, or should — the skill
that wrote the artifact, a project doc — are a lesson: when `self-improve` is available, print it
in one line with its target and offer to run it, never unasked. One-off slips earn no offer.

Ready → hand off the next phase as copy-pasteable launch commands in the syntax of the agent
tool in use (`claude` is only the example), `<slug>` being the artifact's; requirements with a plan
of the same base hand off that plan's next phase in place of create-plan; a line naming a skill
only when that skill is available:

```
claude --name create-plan-<slug> "/create-implementation-plan <path>.REQUIREMENTS.md"               # after requirements
claude --name create-manual-test-<slug> "/create-manual-test-instructions <path>.REQUIREMENTS.md"   # after requirements
claude --name execute-plan-<slug> "Execute the plan <path>.PLAN.md"                                 # after an unsplit plan
claude --name split-plan-tasks-<slug> "/split-plan-tasks <path>.PLAN.md"                            # after an unsplit plan, or a split one a fix reached (replace)
claude --name execute-tasks-<slug> "/execute-plan-tasks <path>.PLAN.md"                             # after a split plan no fix reached
```

Done when all are printed.

## Boundaries

- Files written: the artifact, plus its upstream requirements or derived plan when a fix reaches
  them — no review file, no source code.
- Read-only on the tracker, the repos and git.
