---
name: self-improve
description: Capture durable user feedback into the governing skill/doc, or propose creating a new skill when no suitable one exists, so future sessions don't repeat the mistake. Use when the user rejects, reverts, or overrides the agent's output or approach on something a skill/doc covers or should cover, and when manually invoked to improve or create guidance.
allowed-tools: Read, Write, Edit, Glob, Grep
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.9"
---

# Self-improve

**Suggest** durable improvements to the skill or governing doc that should have steered the agent,
so the next session gets it right without being told again — and apply them only after the user
approves. The skill proposes; the user stays in control of every change. Three ways in:

- **Manual** — the user invokes `/self-improve` to deliberately improve a skill or doc.
- **Self-triggered** — the agent notices it was corrected on something a skill/doc governs (or
  should). Don't silently correct and move on, but don't derail the task either: note the lesson,
  finish what the user asked for, and offer to persist it at the next natural breakpoint.
- **Driven by another skill** — a caller hands over content that is already durable guidance plus an
  already-chosen target (scope, form, and path — possibly a new file). It resolved both with the
  user, so skip steps 1-2 and run only draft + apply.

"Skill/doc" means any standing instruction: a `SKILL.md`, `AGENTS.md`/`CLAUDE.md`, a
coding-standards or convention doc, a rules file — anything that guides future agents.

## Hard rules

- **Confirm before applying.** The skill's job is to **suggest**, never to change text on its own.
  Never edit a skill or doc without the user's explicit go-ahead on the concrete change — present it
  as a diff and apply only on approval, whether the user invoked the skill or the agent
  self-triggered. State plainly whether a change is not yet applied (awaiting approval) or already
  applied (and where), so the user never has to ask.
- **Editing any skill/doc → always route the write through one of two skills to keep it compact;
  never edit it directly.** A `SKILL.md` goes through
  [compact-skill-creator](../compact-skill-creator/SKILL.md); any other doc (rule,
  `AGENTS.md`/`CLAUDE.md`, convention doc) goes through
  [compact-docs-writer](../compact-docs-writer/SKILL.md). Actually invoke the skill and follow its
  workflow *before* drafting or applying; reading it, applying its principles by hand, or naming it
  after a direct edit does not count.

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
   `CLAUDE.md`, convention docs). If one exists, it's the target — and if that rule already existed
   yet failed to steer the agent, the discoverability gap *is* the lesson, not a no-op: don't stop
   at "the rule exists." Diagnose why it didn't fire (buried, in a doc the agent wouldn't open for
   this action, scoped or worded too narrowly, or unenforced) and fix that root cause: surface it
   where the agent looks, tighten its scope, cross-reference it, or propose mechanical enforcement
   (e.g. a lint rule). If none fits, propose a new target and ask before drafting: a new skill for a
   recurring workflow, a new rule for a standing constraint, or the most fitting doc otherwise. Ask
   whenever unsure.
3. **Draft the edit.** Write the rule into the target as the least text that fully captures it:
   agent-agnostic ("the agent", never a vendor name), no process narration, no restating — a real
   durable instruction. Prefer tightening or extending an existing rule over appending a new one.
   If the lesson **reverses** an existing rule, surface that explicitly — show the old rule, the
   feedback, and the proposed replacement — and never overwrite it silently; the contradiction may
   mean the feedback is context-specific, not a true reversal.
4. **Apply the edit.** Route the write per the Hard rules — `SKILL.md` → compact-skill-creator, any
   other doc → compact-docs-writer — presenting a diff and applying only on approval.
