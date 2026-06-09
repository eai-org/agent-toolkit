---
name: refine-ticket
description: Refine a development ticket into a validated, self-contained REQUIREMENTS document — the "what", verified against the codebase. Invoke manually only.
disable-model-invocation: true
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.1"
---

# Refine ticket

The **Refine** phase of Refine → Plan → Act: turn a raw ticket into a validated requirements
document a fresh session can plan from. Analysis only — it defines **what** must be true when the
work is done, never **how** to build it, and never touches code.

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
- Treat "this probably works like X" as a question, not a fact. Keep "I confirmed X", "the ticket
  claims X", and "I assume X" distinct; the latter two never become the first without evidence.
- Before declaring something missing, broaden the search — "not found under the name the ticket
  used" is not "not present".
- Verify both sides of an integration: if a requirement relies on another layer behaving a certain
  way, open that layer and confirm it.

## Grill to resolve every branch

After gathering and code-verifying, run a grilling interview to close every remaining decision:

- One question at a time, each with your recommended answer.
- If a question is answerable from the codebase, answer it by exploring — don't ask.
- Walk each branch of the decision tree, resolving dependencies between decisions, until there is
  shared understanding and no open branch that blocks implementation.

Separate two kinds of uncertainty:
- **Blocking** — implementation can't proceed without it (a contradiction, a missing referenced
  file). Resolve during grilling, before writing the file.
- **Non-blocking** — a reasonable default exists but a human should confirm. Record under Open
  questions with your tentative answer.

## Carry forward what you verified

The facts you confirm while reading the code are part of the output, not scratch work. Where the
relevant code lives, the shape of the data, the existing patterns to reuse — record them so the
planner builds on them instead of rediscovering. Keep these as anchors for the requirements, not a
solution design: *what is true today*, not *how to change it*.

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
- If there is **no local ticket file** (a tracker URL/ID, pasted text), follow the project's
  planning convention for where planning documents live (per the project's or user's rules — don't
  assume a fixed path, ask when not sure). Propose a kebab-case `<slug>` (prefix the tracker id when
  the ticket is bound to one) and the target path, **confirm both with the user**, then write
  `<slug>.REQUIREMENTS.md` there.

Five parts (Overrides and Open questions may be empty — don't pad):

1. **Context** — 1–3 sentences: the feature, what's in scope, what's out.
2. **Requirements** — deduplicated functional + technical list. Tag each item with its ticket source
   (e.g. `(Description)`, `(Technical Detail)`, `(AC)`). Group by area when it aids reading. Cite the
   concrete file path / identifier inline wherever a requirement touches code; cite a reused pattern
   as `path:line-range`.
3. **Overrides** — where the ticket says one thing and the requirement says another (ticket is
   stale, wrong, or self-contradictory). Each entry: what the ticket says, what the code/AC shows,
   the resulting requirement.
4. **Open questions** — non-blocking ambiguities, each with your tentative answer and why it's
   non-blocking. Blocking questions never appear here.
5. **Acceptance criteria** — flat, verifiable checklist the implementation must satisfy.

Each requirement is self-contained; user-facing strings that must stay in a given language are
quoted verbatim.

## Boundaries

- Do **not** write an implementation plan or describe "how".
- Do **not** modify any source files. The only file you write is the REQUIREMENTS document.

When done, state — in **project-relative paths** — that the requirements file is ready, then suggest
the next steps:

```
Next: /create-manual-test-instructions <path>.REQUIREMENTS.md   # QA manual test
Then: /create-implementation-plan <path>.REQUIREMENTS.md        # Plan phase
```
