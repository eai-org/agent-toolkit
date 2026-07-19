---
name: refine-ticket
description: Refine a development ticket — or brainstorm a raw idea — into a validated, self-contained REQUIREMENTS document — the "what", verified against the codebase. Invoke manually only.
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.12"
---

# Refine ticket

The **Refine** phase of Refine → Plan → Act: turn a raw ticket — or an idea to brainstorm — into a
validated requirements document a fresh session can plan from. Analysis only — it defines **what**
must be true when the work is done, never **how** to build it, and never touches code.

An idea is a ticket that doesn't exist yet: treat the user's words as the ticket text, and grill
to shape the idea itself — goal, in vs out of scope — before closing the branches that block
implementation.

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
  claims X", and "I assume X" distinct; the latter two never become the first without evidence.
- Before declaring something missing, broaden the search — "not found under the name the ticket
  used" is not "not present".
- Verify both sides of an integration: if a requirement relies on another layer behaving a certain
  way, open that layer and confirm it.

## Grill to resolve every branch

After gathering and code-verifying, **grill** the user — interview relentlessly, never guessing
what they could clarify — to close every remaining decision:

- One question at a time, each with your recommended answer.
- If any part of a question is answerable from the codebase, explore it rather than ask — never
  bundle a code-answerable sub-question into a grill. "Which name, type, shape, or pattern fits?" is
  code-answerable: match the closest existing analogue, and let that verified convention outrank the
  ticket's contrary suggestion. Grill only on what genuinely remains (product intent, cross-task
  timing).
- Walk each branch of the decision tree, resolving dependencies between decisions, until there is
  shared understanding and no open branch that blocks implementation.

Separate two kinds of uncertainty:
- **Blocking** — implementation can't proceed without it (a contradiction, a missing referenced
  file). Resolve during grilling, before writing the file.
- **Non-blocking** — a reasonable default exists but a human should confirm. Record under Open
  questions with your tentative answer.

## "Already exists" / "reuse X" is a directive

When the ticket says a capability exists or names something to reuse, find what's *behind* it (the
service method, query, SP it calls) and anchor the requirement on the smallest extension — relax a
parameter, widen a filter, lift a guard. "Not an exact match" doesn't license a net-new build:
reuse-vs-build-new is a **blocking** question for the user, never a silent default.

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
`.TICKET.md` before grilling; for tracker-only references, judge relevance before fetching. What a
sibling supplies — execution order, contracts it owns, superseded-spec notes — is context only,
never requirements: scope stays this ticket's, and anything a sibling suggests changing is a
question for the user, never a silent scope change.

## Output: the REQUIREMENTS file

Must stand alone for a **fresh session** with no memory of this conversation and no access to the
ticket — this is the single most important constraint. No "as discussed", "we agreed", or "see
ticket".

Location:
- If the ticket input is a **local file**, write the REQUIREMENTS file in the **same directory**,
  replacing `.TICKET` with `.REQUIREMENTS` (e.g. `FOO.TICKET.md` → `FOO.REQUIREMENTS.md`); if the
  input doesn't follow that convention, append `.REQUIREMENTS` before `.md`.
- If there is **no local ticket file** (a tracker URL/ID, pasted text), follow the project's/user's
  convention for where planning documents live (default: `.agents/plans/`). Propose a kebab-case
  `<slug>` (prefix the tracker id when the ticket is bound to one) and the target path, **confirm
  both with the user**, then write `<slug>/<slug>.REQUIREMENTS.md` there.

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
3. **Requirements** — deduplicated functional + technical list. Tag each item with its ticket source
   (e.g. `(Description)`, `(Technical Detail)`, `(AC)`). Group by area when it aids reading. Cite
   the concrete file path / identifier inline wherever a requirement touches code; cite a reused
   pattern as `path:line-range`.
4. **Overrides** — where the ticket says one thing and the requirement says another (ticket is
   stale, wrong, or self-contradictory). Each entry: what the ticket says, what the code/AC shows,
   the resulting requirement.
5. **Open questions** — non-blocking ambiguities, each with your tentative answer and why it's
   non-blocking. Blocking questions never appear here.
6. **Acceptance criteria** — flat, verifiable checklist the implementation must satisfy.

Each requirement is self-contained; user-facing strings that must stay in a given language are
quoted verbatim.

## Boundaries

- Do **not** write an implementation plan or describe "how".
- Do **not** modify any source files. The only file you write is the REQUIREMENTS document.

When done, state — in **project-relative paths** — that the requirements file is ready, then hand
off each next phase as a **single copy-pasteable launch command** — phase-prefixed session name and
prompt combined, so one paste starts the session. Use the launch syntax of the agent tool in use
(vendor-agnostic — `claude` below is only the example), naming the session with the phase prefix
plus the requirements file's slug:

```
claude --name create-manual-test-<slug> "/create-manual-test-instructions <path>.REQUIREMENTS.md"   # QA manual test
claude --name create-plan-<slug> "/create-implementation-plan <path>.REQUIREMENTS.md"               # Plan phase
```

The phase prefix (`create-plan-`, `execute-plan-`, …) keeps the pipeline phases distinguishable in
the session list.

Then offer the plan phase's alternative — clearing the current session instead (vendor-agnostic —
`/clear` below is only the example; use the clear command of the agent tool in use):

OR /clear and run:

```
/create-implementation-plan <path>.REQUIREMENTS.md
```
