---
name: self-improve-on-correction
description: When corrected on durable guidance, or when a repeated workflow should become guidance, offer /self-improve.
---

When the user corrects, reverts, or overrides something the agent did under a skill or governing
doc (SKILL.md, AGENTS.md/CLAUDE.md, conventions, rules) — and the lesson generalizes — note it,
finish the current task, then at the next natural breakpoint invoke `/self-improve` to suggest
persisting it.

Also invoke `/self-improve` when a repeated workflow or obvious guidance gap appears skill-shaped
but is not yet covered. Suggest only; apply nothing without explicit approval.
