---
name: review-ticket
description: Triage a board ticket before work starts: fetch it, compare it against the codebase, and print a plain recap plus only the high-cost questions worth raising. The review prints to the terminal and is saved only when asked.
disable-model-invocation: true
license: MIT
metadata:
  author: Francesco Borzì
  version: "0.2"
---

# Review ticket

A pre-pickup triage glance: read a ticket, usually before anyone has started it, and decide
whether it can be picked up or something must be clarified first. The output is a short recap plus
the questions worth asking, aimed at whoever owns the requirements, not at you.

## Gather: delegate to fetch-ticket

Input is a ticket URL or a bare id/key. Invoke [fetch-ticket](../fetch-ticket/SKILL.md) on it: it
resolves the input and fetches. If the input is ambiguous or unrecognized, ask rather than guess.
fetch-ticket persists the `.TICKET.md` plus attachments and design frames to the planning dir, and
pulls in comments and related-link metadata. Read what it produced, **visually inspecting the
downloaded images and design frames**, which are part of the spec and often where the gaps hide.

**Related tickets.** fetch-ticket lists related items shallowly (title, status, type). Deep-dive
only the parent or dependency tickets that bear on whether work can start or on an accurate recap,
e.g. an open prerequisite that gates this one. Stop once "does this block starting?" is answered.
Never recurse the whole graph.

## Compare against the codebase

Weigh the ticket against the current code at adaptive depth: shallow by default, deeper only to
(a) ground the recap in how the code behaves today and (b) settle whether a real blocker exists.
This is not an exhaustive both-sides verification: go as deep as a specific doubt demands, no
more.

## The question bar: both gates, or stay silent

A question reaches the output only when it clears **both**:

1. **Decision-expensive**: the answer blocks starting, or would be costly to reverse because it
   shapes the implementation (architecture, data model, approach). Cheap, easily-changed details
   (a color, a label, wording, spacing) are dropped even when unspecified.
2. **Not answerable from the materials**: if the ticket, the code, or the design settles it, settle
   it silently. Never ask what you can read.

**Zero questions is a clean, common result**: the ticket is ready to pick up. Never pad to look
thorough.

## Output

Terminal text only (to save it, see Saving):

1. **Verdict line** first, so the answer lands at once, e.g.
   `2 questions to resolve before starting` or `Looks ready to pick up, no blockers.`
2. **Recap**: a few plain sentences in simple words covering what the ticket wants, the goal, and a
   before/after where it clarifies, grounded in the real current behavior you saw in the code.
3. **Questions**, when any cleared both gates: a numbered list, each item bracketed top and bottom
   by a ~40-char rule of `━` so the eye jumps between them. Each item carries the **question**
   (paste-ready, in a natural human voice, no AI tells, no dashes, citing the ambiguous part of the
   ticket or the relevant code to stay concrete) and a short **why-it-matters note to you** for
   deciding whether to forward it. When nothing cleared both gates, print only the verdict line.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 1 · <short label>

Question to ask, a sentence or two in a real person's voice.

Why it matters: the cost if we guess wrong.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Saving

Off by default: the review lives in the terminal. Only when the user explicitly asks to save, write
it as `<id>-<slug>.REVIEW.md` next to the `.TICKET.md` in the planning dir. With no blockers you may
add one terse line pointing at the next step (`/refine-ticket <ticket-file>`), nothing more.

## Boundaries

- **Read-only on tracker and code.** Never modify the tracker (comments, transitions, edits) or any
  source file. The only files written are fetch-ticket's `.TICKET.md` and attachments, plus the
  `.REVIEW.md` when explicitly asked.
- **Non-interactive on requirements.** The questions are the output: never grill the user to
  resolve them. Ask the user only operational things (an ambiguous tracker/ticket, a fetch that
  needs input), never requirement decisions.
