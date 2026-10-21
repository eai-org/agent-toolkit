---
name: grill-me
description: Interview the user relentlessly about a plan, design, or idea until reaching shared understanding, resolving each branch of the decision tree. Use when the user wants to stress-test a plan, validate an idea, get grilled on their design, or says "grill me".
license: MIT
metadata:
  version: "0.2"
  author: Matt Pocock + additional edits
---

Interview the user relentlessly about every aspect of their plan, design, or idea until you reach
a shared understanding. Walk down each branch of the design tree, resolving dependencies between
decisions one by one.

- One question at a time, each with your recommended answer, worded so that "yes" accepts it, via
  `explain-in-simple-language` when available.
- Facts are yours to find (codebase, docs, tool output): look them up, never ask. Decisions are
  the user's: put each one to them and wait.

Done when no branch is open and nothing is silently assumed. Then print the settled decisions as a
short list (decision, chosen answer, one-line why) the user can paste into the plan, ticket or
doc, and stop: act on it only after the user confirms.
