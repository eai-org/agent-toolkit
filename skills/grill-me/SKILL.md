---
name: grill-me
description: Interview the user relentlessly about a plan, design, or idea until reaching shared understanding, resolving each branch of the decision tree. Use when the user wants to stress-test a plan, validate an idea, get grilled on their design, or says "grill me".
license: MIT
metadata:
  version: "0.3"
  author: Matt Pocock + additional edits
---

Interview the user relentlessly about every aspect of their plan, design, or idea until you reach
a shared understanding. Walk down each branch of the design tree, resolving dependencies between
decisions one by one.

- One question at a time, each with your recommended answer and its reason, worded so that "yes"
  accepts it, via `explain-in-simple-language` when available.
- Ask only what changes the plan; when every likely answer leads to the same plan, state the
  assumption instead.
- Facts are yours to find (codebase, docs, tool output, what the user's own edits show): look them
  up, never ask. Decisions are the user's: put each one to them and wait.
- The user is short on time or leaves the rest to you → take the open recommendations, mark them
  provisional, and close.

Done when no branch that changes the plan is open and every assumption is stated. Then open with
the one confirmation you need, print the settled decisions as a short list (decision, chosen
answer, one-line why; provisional ones marked) the user can paste into the plan, ticket or doc,
and stop: act on it only after the user confirms.
