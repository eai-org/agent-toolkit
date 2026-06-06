---
name: compact-skill-creator
description: Author or refine a skill for maximum token economy without losing intent. Use when creating a new skill or improving an existing `SKILL.md`.
allowed-tools: Read, Write, Edit, Glob, Grep
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.0"
---

# Compact skill creator

Author a new skill, or improve an existing one, so it carries **all** its rules and intent in the
**least text possible**. Cost has two tiers: the `description` sits in context *every* session — the
skill's most expensive text — while the body loads only when the skill triggers. Both stay lean. Be
interactive: gather what you need, draft, then apply only on approval.

## Core principle

Write each piece of information with the least text that still preserves every rule, constraint,
edge case, and intent. Two directions, equally binding:

- Cut duplication, filler, and anything restatable more briefly.
- **Never** drop text whose removal loses information or instruction, just to be shorter.

Recurring reflex: *"Can this exact rule be said in fewer words?"* — if yes, do it.

## Trigger taxonomy — classify first

How a skill is triggered decides how its `description` is written. Classify into one:

- **Mandatory** — must auto-load *whenever* a task type is touched (e.g. "working on UI components",
  "dealing with unit tests"). A silent miss defeats its purpose, so the description **spends words**
  on a strict, concrete trigger: concrete verbs + the artifact ("when creating, editing, or
  reviewing …").
- **Manual** — invoked deliberately (e.g. a `/command`). No trigger bait; the description just
  states what it does so a human choosing from a list understands it.
- **Self-Evident** — auto-loadable, but intent is obvious from a natural request (e.g. "fetch a
  ticket"). Trigger words ≈ the task name, so a short description routes correctly without a
  when/when-not clause.

Governing rule: **description tokens are justified only by trigger precision, never by summary.**
Compress *within* a type — but never starve a Mandatory trigger to save a few tokens.

## Agnosticism

- **Agent-agnostic — hard rule.** Say "the agent" / "the session"; never vendor names ("Claude
  Code", "Claude", etc.). When improving a skill, flag and fix violations.
- **Project-agnostic — best-effort.** Default to generic wording. Couple to a project/framework/tool
  only when the skill's purpose requires it; when you must, keep it explicit and contained —
  declared up front or in a referenced doc — but skip a standalone declaration when the body already
  names the coupled artifacts throughout, since restating them only duplicates.

## Progressive disclosure — when to split

A skill folder can hold a lean `SKILL.md` that references supporting `.md` docs. A referenced doc
loads **only when the agent follows the pointer** — that is the lever.

- **Primary criterion: conditional relevance.** Extract content needed only in a sub-case (rare
  branch, long reference table, worked example, framework-specific detail). Keep always-needed
  instructions inline.
- **Size only modulates:** large conditional chunks are strong candidates; tiny ones stay inline (a
  pointer plus a round-trip can cost more than it saves). These are signals, not hard limits.
- Test: *"Needed on every invocation, or only in a sub-case — and big enough that inlining taxes
  every invocation? If both, extract it."*

## Workflow

1. **Detect mode.** A path/skill argument → improve; none → create. To create, put the skill in its
   own folder alongside existing skills, following the project's convention — ask the user if it's
   unclear; folder name and `name` field must match, in kebab-case.
2. **Intake — interview relentlessly to shared understanding.** Before drafting, walk down each
   branch of the skill's design tree, resolving dependencies between decisions one at a time —
   never fire a fixed batch of questions once and then draft. Cover at least the purpose, **trigger
   type**, and any unavoidable coupling, plus whatever each answer opens up. Ask one question at a
   time, each with your recommended answer; if a question can be answered by exploring the codebase,
   explore instead of asking. Scale depth to complexity (complex skill → more questions; simple →
   few). The only limit: never interview for its own sake.
3. **Metadata.** Always include the frontmatter fields; never hardcode their values. Creating: infer
   defaults from context (sibling `SKILL.md` files, `git config user.name`, repo `LICENSE`), ask the
   user to confirm or override, and start version at `"1.0"`. Improving: preserve existing fields,
   and ask the user whether to bump the version or add any missing field.
4. **Draft** (create) or **improve** (existing). Improving cuts redundancy *and* adds or clarifies
   where the skill is vague, under-specified, or missing a rule — loop back to intake for more
   questions if gaps surface.
5. **Self-review** before presenting (terse yes/no checks):
   - Every original rule/intent still present?
   - Wording agent-agnostic? Project coupling contained?
   - Trigger type identified, and the description written to fit it? Then test the description:
     reading only it, would an agent open the skill for the intended task (must be yes) and skip it
     for a similar but unrelated task (must be no)? Reword until both hold.
   - Duplication/filler gone?
   - When removing text: list each removed item and confirm it is filler/duplication, not intent.
6. **Present** the proposed change as a diff with a token/word delta (for improve mode); apply only
   on approval.
