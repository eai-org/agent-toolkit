---
name: verify-understanding
description: Verify the engineer is ready to implement a feature through a teach-back conversation over its ticket review.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "1.2"
---

# Verify understanding

One goal, nothing more, nothing less: verify the engineer is ready to move to the implementation
phase. Exercise their understanding of a feature before they work on it — the pipeline's other
artifacts serve fresh agent sessions; this step serves the human. Active recall: the user produces
the feature in their own words, you only steer and fix. Re-runnable: right after the ticket
review, or days later just before implementation — every run starts fresh from the review file, no
state kept between runs.

## Input

A `.TICKET-REVIEW.md`. Read it and the ticket files and parent it links. A reference that exists
only as a tracker URL (no local file) may be read from the tracker at conversation time. A ticket
with a newer `-vN` fetch beside the one the review read has likely overtaken it: say so, read the
newest ticket files, and treat the review's open questions as possibly answered there. A
`.REQUIREMENTS.md` of the same base is read for its Overrides, which win over the ticket text.
Given a ticket file and no review, ask whether to run `/review-ticket` first when it is installed;
never improvise the review.

## The conversation

A conversation, not a test — the last sync between a dev and their PO before development starts.
Word your probes and corrections via `explain-in-simple-language` when available.

1. Ask the user to explain the feature in their own words: who uses it, what they see and do, why
   the feature exists, and what each ticket contributes.
2. Let them produce the narrative. Probe one weak spot at a time; correct and complete only from
   the review file and the referenced materials — flag what those don't settle, never improvise
   requirements.
3. Stay at that PO–dev depth: journey, actors, purpose, per-ticket contribution — not DTO,
   field, or architecture detail.

When the product's user-facing language differs from the conversation's, name each page, text, or
element with its user-facing term in parentheses — "the client area (klantportaal)".

Done when the user has correctly produced — corrections absorbed — the journey, why the feature
exists, and every input ticket's contribution: enough to start implementing. Close with a short
wrap-up naming anything that stayed shaky, then, only when refine-ticket is installed, hand off
one copy-pasteable launch command per ticket in the set's suggested execution order, in the syntax
of the agent tool in use (`claude` is only the example):
`claude --name refine-<slug> "/refine-ticket <ticket-file>"`; then the alternative, the tool's
clear command (`/clear` is only the example) followed by `/refine-ticket <ticket-file>`.

## Boundaries

- The conversation is the product: write no files.
- Read-only on the tracker.
