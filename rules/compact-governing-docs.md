---
name: compact-governing-docs
description: Before writing a governing doc (`AGENTS.md`/`CLAUDE.md`, rules, SKILL.md) or a doc it references, run the matching compaction skill — `/compact-docs-writer`, or `/compact-skill-creator` for a SKILL.md — to keep it compact.
---

Before writing or editing a governing doc (`AGENTS.md`/`CLAUDE.md`, `rules/*.md`, `SKILL.md`,
convention docs) or any doc it references (directly or indirectly), run the matching compaction
skill up front, not as a later cleanup, so each rule stays as compact as possible: a `SKILL.md`
through `/compact-skill-creator`; any other doc through `/compact-docs-writer`.

Editing again later in the session requires a fresh invocation — an earlier one still in context
doesn't count.
