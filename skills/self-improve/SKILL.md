---
name: self-improve
description: Capture user feedback into the skill or governing doc (SKILL.md, AGENTS.md/CLAUDE.md, coding-standards, etc.) that should have prevented a mistake, so future sessions don't repeat it. Use when the user rejects, reverts, or overrides the agent's output or approach on something a skill or governing doc covers (or should), and when manually invoked to improve a skill/doc.
allowed-tools: Read, Write, Edit, Glob, Grep
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.1"
---

# Self-improve

**Suggest** durable improvements to the skill or governing doc that should have steered the agent,
so the next session gets it right without being told again — and apply them only after the user
approves. The skill proposes; the user stays in control of every change. Two ways in:

- **Manual** — the user invokes `/self-improve` to deliberately improve a skill or doc.
- **Self-triggered** — the agent notices it was corrected on something a skill/doc governs (or
  should). Don't silently correct and move on, but don't derail the task either: note the lesson,
  finish what the user asked for, and offer to persist it at the next natural breakpoint.

"Skill/doc" means any standing instruction: a `SKILL.md`, `AGENTS.md`/`CLAUDE.md`, a
coding-standards or convention doc, a rules file — anything that guides future agents.

## Hard rules

- **Confirm before applying.** The skill's job is to **suggest**, never to change text on its own.
  Never edit a skill or doc without the user's explicit go-ahead on the concrete change — present it
  as a diff and apply only on approval, whether the user invoked the skill or the agent
  self-triggered.
- **Editing a `SKILL.md` → always invoke [compact-skill-creator](../compact-skill-creator/SKILL.md)**
  to keep skills compact and ergonomic; never edit one directly.

## Recognize a persistable correction (self-trigger)

Signals the agent was corrected in a way worth persisting: the user rejects or reverts a choice
("no, do X instead"), states a standing preference ("we always…", "never…"), or redirects an action
the agent took under a skill or doc.

**Only persist a *durable* lesson** — one that generalizes and will recur. Skip one-off,
task-specific tweaks that won't apply next time; persisting those pollutes the docs.
Whenever unsure whether it generalizes, ask the user.

## Workflow

1. **Capture the lesson.** State, in one line, the general rule the feedback implies — not the
   surface incident ("Mock external HTTP in unit tests," not "the agent mocked the wrong call").
2. **Locate the target.** Find which skill/doc governs this action (search skills, `AGENTS.md`/
   `CLAUDE.md`, convention docs). If one exists, it's the target. If none does and the lesson is
   broad, propose the most fitting doc (or, with the user, a new one). Ask whenever unsure.
3. **Draft the edit.** Write the rule into the target as the least text that fully captures it:
   agent-agnostic ("the agent", never a vendor name), no process narration, no restating — a real
   durable instruction. Prefer tightening or extending an existing rule over appending a new one.
   If the lesson **reverses** an existing rule, surface that explicitly — show the old rule, the
   feedback, and the proposed replacement — and never overwrite it silently; the contradiction may
   mean the feedback is context-specific, not a true reversal.
4. **Apply the edit.** Skill-file target → use the compact-skill-creator route (see Hard rules).
   Non-skill doc → present the diff yourself. Either way, apply only on approval.
