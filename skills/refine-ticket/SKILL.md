---
name: refine-ticket
description: Refine a development ticket — or brainstorm a raw idea — into a validated, self-contained REQUIREMENTS document — the "what", verified against the codebase. Invoke manually only.
license: MIT
metadata:
  version: "1.21"
---

# Refine ticket

The **Refine** phase of Refine → Plan → Act: turn a raw ticket — or an idea to brainstorm — into a
validated requirements document a fresh session can plan from. Analysis only — it defines **what**
must be true when the work is done, never **how** to build it, and never touches code.

An idea is a ticket that doesn't exist yet: treat the user's words as the ticket text, and grill
to shape the idea itself — goal, in vs out of scope — before closing the branches that block
implementation.

## Input

A `.TICKET.md` path, a ticket URL or bare id, or an idea in words. When the harness has subagents
and fetch-ticket is available (`../fetch-ticket/SKILL.md` beside this skill), a URL or id is
fetched first by a subagent per fetch-ticket's [delegate.md](../fetch-ticket/delegate.md) — one
ticket per run; several → point at a fetch session instead, which handles sets. A non-empty warn
list stops for one question: supply the files now (`/attach-to-ticket` when available; answered
by running it → resume with the supplied files once it reports) or refine without them. The
fetched file is then the local ticket file. No subagents, or fetch-ticket not available → read
the ticket from its tracker and refine with no local ticket file.

An existing `.REQUIREMENTS.md` (a re-run, e.g. once a blocking answer is in): read it and its
ticket file (`.REQUIREMENTS` → `.TICKET`, or its latest `-vN` re-fetch, file or directory) first
— none for a tracker ticket → re-read it there, asking for its URL or id when the file doesn't
name it; grill only on what changed since, and update it in place.

## What, not how — but verified against the code

You cannot define the "what" in a vacuum. Every requirement must be checked against the **actual
code, config, and design** — a ticket may be stale, ambiguous, contradicted by the codebase, or
depend on upstream work that isn't implemented yet (e.g. a prerequisite ticket still open). Reading
the code here is for *validating* requirements, not for designing the solution.

## Golden rule: never guess — ask

- Anything determinable by reading the code, resolve by reading the code — never ask the user about
  it.
- Anything *not* determinable from ticket + code, ask — never fill the gap with a plausible
  assumption.
- Local environment state (config files, DB contents, env vars) describes only the machine it's on
  — never assume it matches the environment where the reported behaviour occurred; ask the user to
  confirm such values.
- Treat "this probably works like X" as a question, not a fact. Keep "I confirmed X", "the ticket
  claims X", and "I assume X" distinct; the latter two never become the first without evidence. A
  decision marked settled by a ticket or design carries the quote that settles it; no quote, still
  open.
- Before declaring something missing, unique or unhandled ("no X does Y", "X's only user", "the
  existing ones don't cover Z"), search every repo the feature spans for the concept — "not found
  under the name the ticket used" is not "not present".
- Verify both sides of an integration: if a requirement relies on another layer behaving a certain
  way, open that layer and confirm it.

## Reconcile against the design when one is referenced

When a ticket points at a design (mockup, screenshot, prototype, design-tool link), that design is
part of the spec. Visual decisions made without seeing it lock in wrong defaults.

- If you cannot actually see the referenced design, ask for it before proceeding. A link you can't
  render is not a design you've read. Prefer a copy already saved with the ticket over re-fetching.
- Once you can see it, treat visual specifics as contract-level: currency, date, and number
  formatting, empty and error states, label wording, spacing, alignment, iconography. The default
  for "is this in the design?" is match the design, not do the minimum.
- Any visual choice you'd otherwise make blind is an Open question, never silently defaulted.

## Read relevant related tickets — context, not scope

When the ticket references others that matter to it (BE/FE counterparts, dependencies, follow-ups),
read them too — they complete the picture and sharpen how this ticket's requirements are meant. A
`## Ticket set` section in the ticket file lists locally fetched siblings: read every linked
`.TICKET.md` before grilling; for tracker-only references, judge relevance before fetching, then
fetch one the way Input does. What a sibling supplies — execution order, contracts it owns,
superseded-spec notes — is context only, never requirements: scope stays this ticket's, and
anything a sibling suggests changing is a question for the user, never a silent scope change.

## A prior ticket review is leads, never facts

Unless one was passed in, look for a `.TICKET-REVIEW.md` next to the ticket or in its set
directory, preferring the one whose base matches the ticket file's `-vN` base — an earlier
session's triage; say which one you use, or that none exists. Challenge and re-verify everything
in it before relying on it (its citations make that cheap). Its shipped questions are blocking
items: grill first whether the owner answered. The defaults it assumed for dropped cheap details
are decisions to close here — grilled or recorded as Open questions, never adopted silently.
Handoffs are out-of-scope dependencies; verdict and walkthrough are context only. The ticket file
and the code always win; a review older than the ticket file has likely been overtaken — say so.

## Existing requirements

Before the first grill question, look for this ticket's requirements: the `.REQUIREMENTS.md` at
the target path (Location below) or, for a ticket with `-vN` versions and none under its own base,
the highest earlier version's (down to the unsuffixed base). A tracker ticket with no local file
has its slug and target path confirmed before the first grill question, so the check runs there;
an idea in words has them confirmed once its goal and scope are shaped, before the branch
grilling, and the check runs then, at that path only. Found and not the input → say so, name the
`.PLAN`/`.MANUAL-TEST` of that base that would go stale, and ask once:

- **Update in place** (recommended): read that file and the highest `-vN` ticket first, grill only
  on what changed, keep settled decisions, update the same file.
- **Start over**: same base → replace it at write time; an earlier version → fresh requirements
  under this ticket's base, old file untouched.

Never a `-vN` REQUIREMENTS copy beside a ticket of another base; never asked again at write time.

## Grill to resolve every branch

After gathering and code-verifying, **grill** the user — interview relentlessly, never guessing
what they could clarify — to close every remaining decision:

- One question at a time, each with your recommended answer, worded so that "yes" accepts it, via
  `explain-in-simple-language` when available.
- Facts are yours to find (codebase, docs, tool output): look them up, never ask. Decisions are
  the user's. Never bundle a code-answerable sub-question into a grill: "Which name, type, shape,
  or pattern fits?" is code-answerable — match the closest existing analogue, and let that
  verified convention outrank the ticket's contrary suggestion. Grill only on what genuinely
  remains (product intent, cross-task timing).
- Walk each branch of the decision tree, resolving dependencies between decisions, until there is
  shared understanding and no open branch that blocks implementation.

Separate two kinds of uncertainty:
- **Blocking** — implementation can't proceed without it (a contradiction, a missing referenced
  file). Resolve during grilling, before writing the file.
- **Non-blocking** — a reasonable default exists but a human should confirm. Record under Open
  questions with your tentative answer.

A blocking question only someone else can answer: write the file anyway, with the question under
Open questions marked **blocking**, naming who answers it and the question drafted ready to send
(via `use-conversational-language` when available). Print no hand-off commands while a blocking
entry exists, only the one for once the answer is in: `/refine-ticket <path>.REQUIREMENTS.md`.

## Bug tickets

A ticket is a bug when its tracker type says so (a fetched file's `**Type**` header line, else the
tracker's type field); with no type (an idea, pasted text, a typeless tracker), when its text
reports existing behaviour breaking what should already work, not a wish to change what works as
intended. A non-bug type whose text reads like a bug, or a case neither settles, is a grill
question.

For a bug, try to reproduce it with what the project already provides (running the app, an
existing command or test), the smallest that shows it: a unit test before an integration test
before e2e or the running app, a larger one only when the bug lies in how parts connect. No
scratch script, no source edit, no tracked file written. A run's side outputs (build output,
caches, coverage, reports, snapshots) may land only in scratch space or git-ignored paths; a run
that would write elsewhere is not made, and the bug counts as not reproduced. A run acting on
shared or external state (a remote service, a shared database) is a grill question, never made
unasked.

Not reproduced (the attempt didn't show it, or nothing in the project can try it, e.g. a
production-only or external-integration bug) is a grill question on where it occurred
(environment, data, version), per the Golden rule's local-environment line; never assume it fixed
or invalid. Still unreproduced after grilling → the Reproduction part says so and why; that alone
is not blocking.

## "Already exists" / "reuse X" is a directive

When the ticket says a capability exists or names something to reuse, find what's *behind* it (the
service method, query, SP it calls) and anchor the requirement on the smallest extension — relax a
parameter, widen a filter, lift a guard. "Not an exact match" doesn't license a net-new build:
reuse-vs-build-new is a **blocking** question for the user, never a silent default.

## Output: the REQUIREMENTS file

Must stand alone for a **fresh session** with no memory of this conversation and no access to the
ticket — this is the single most important constraint. No "as discussed", "we agreed", or "see
ticket".

Location:
- If the ticket input is a **local file**, write the REQUIREMENTS file in the **same directory**,
  replacing `.TICKET` with `.REQUIREMENTS` (e.g. `FOO.TICKET.md` → `FOO.REQUIREMENTS.md`); if the
  input doesn't follow that convention, append `.REQUIREMENTS` before `.md`.
- If there is **no local ticket file** (a tracker URL/ID read without a fetch, pasted text),
  follow the project's/user's convention for where planning documents live (default:
  `.agents/plans/`). Propose a kebab-case `<slug>` (prefix the tracker id when the ticket is bound
  to one) and the target path, **confirm both with the user** (timing under Existing
  requirements), then write `<slug>/<slug>.REQUIREMENTS.md` there.
- A REQUIREMENTS input is its own target. An existing target is updated or replaced as settled
  under Existing requirements — never asked again here.

Six parts (Verified codebase facts, Overrides, and Open questions may be empty — don't pad):

1. **Context** — 1–3 sentences: the feature, what's in scope, what's out. When the work is only
   a slice of a larger feature, link the big-picture reference (parent story, final-goal/context
   note, design) so the planner sees how it fits; a self-contained task needs none.
2. **Verified codebase facts** — the facts confirmed while validating requirements, recorded so
   the planner builds on them instead of rediscovering: where the relevant code lives, data
   shapes, existing analogues, integration points. Byproduct only — never explore beyond what
   refinement itself needs — and only facts a fresh session would need a search to rediscover.
   Anchor to paths and identifiers; line numbers are hints — they drift. *What is true today*,
   never *how to change it*. When non-empty, open with one line pinning the commit (short hash,
   noting uncommitted changes if the tree is dirty) and absolute date, warning the code may have
   changed since and specifics need re-verifying.
3. **Requirements** — deduplicated functional + technical list. Tag each item with its source in
   the input: a ticket field (`(Description)`, `(AC)`, `(Comment)`), the user's idea statement
   (`(Idea)`), a grilling answer (`(Grilling)`), a review comment by its opening words and
   `path:line` (`("Validate both new option arguments", install.sh:88)`) — never an answers-sheet
   row number. Group by area when it aids reading. Cite the concrete file path / identifier inline
   wherever a requirement touches code; cite a reused pattern as `path:line-range`.
4. **Overrides** — every deviation from the ticket in what must be true when the work is done: a
   ticket statement changed or dropped, a requirement added. Rewording and merged duplicates are not
   deviations; for an idea, only changing or dropping one of the user's own statements is one —
   requirements shaped while grilling are not. Each entry: what the ticket says or omits, the
   resulting requirement, and the reason with its source — what the code/AC shows, or the user's
   decision while grilling.
5. **Open questions** — non-blocking ambiguities, each with your tentative answer and why it's
   non-blocking. A blocking question appears here only marked **blocking**: one someone else must
   answer (above).
6. **Acceptance criteria** — flat, verifiable checklist the implementation must satisfy.

A bug adds a **Reproduction** part right after Context: the steps, what they show now (observed),
what they should show (expected), and whether you reproduced it and how, or why not.

Each requirement is self-contained; user-facing strings that must stay in a given language are
quoted verbatim.

Done when the six parts, plus Reproduction for a bug, are present and
`grep -niE "as discussed|we agreed|see ticket|as mentioned"` on the file returns nothing.

## Boundaries

- Do **not** write an implementation plan or describe "how".
- Do **not** modify any source files. The only files written, a reproduction run's side outputs
  aside (Bug tickets), are the REQUIREMENTS document, the ticket file a delegated fetch-ticket
  writes, and the assets and ticket entries an `/attach-to-ticket` run in answer to the attachments
  question writes.

When done, state — in **project-relative paths** — that the requirements file is ready, then hand
off each next phase as its own fenced block under the label quoted below, holding one
copy-pasteable launch command — phase-prefixed session name and prompt combined, so one paste starts
the session — in the launch syntax of the agent tool in use (vendor-agnostic — `claude` below is
only the example), the session named with the phase prefix plus the requirements file's slug; a
block only when its skill is available, in either form:

"Harden the requirements first, so a fresh reviewer challenges them before planning:"

```
claude --name harden-requirements-<slug> "/harden-artifact <path>.REQUIREMENTS.md"
```

"Plan the implementation:" (starting "or" when the harden block precedes it)

```
claude --name create-plan-<slug> "/create-implementation-plan <path>.REQUIREMENTS.md"
```

"Write the QA manual test:"

```
claude --name create-manual-test-<slug> "/create-manual-test-instructions <path>.REQUIREMENTS.md"
```

The phase prefix (`create-plan-`, `execute-plan-`, …) keeps the pipeline phases distinguishable in
the session list.

Then offer the alternative: one line offering to clear the current session (vendor-agnostic —
`/clear` is only the example; use the clear command of the agent tool in use) and run the next
phase here, then the same labelled blocks with the bare prompts.
