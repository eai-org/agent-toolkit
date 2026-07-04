---
name: compact-skill-creator
description: Author or refine a skill for maximum token economy without losing intent. Use when creating any new skill or editing an existing `SKILL.md`.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.12"
---

# Compact skill creator

Author a new skill, or improve an existing one, so it carries **all** its rules and intent in the
**least text possible**. Cost has two tiers: the `description` sits in context *every* session — the
skill's most expensive text — while the body loads only when the skill triggers. Both stay lean. Be
interactive: gather what you need, draft, then apply only on approval.

## Compaction — always via compact-docs-writer

The compaction rules — the least-text principle, the removal-audit verification, and the
present-and-confirm with a measured word delta — live in
[compact-docs-writer](../compact-docs-writer/SKILL.md), the single source of truth; this skill never
restates or re-derives them. From the moment you draft (step 4) through self-review (step 5) and
present (step 6), **always** invoke compact-docs-writer and follow its workflow on the skill text —
reading it, applying its principles by hand, or naming it after a direct edit does not count. This
skill adds only the skill-specific layer: trigger taxonomy, agnosticism, progressive disclosure,
completion criteria, metadata, and the version-bump decision.

## Trigger taxonomy — classify first

How a skill is triggered decides how its `description` is written. Classify into one:

- **Mandatory** — must auto-load *whenever* a task type is touched (e.g. "working on UI components",
  "dealing with unit tests"). A silent miss defeats its purpose, so the description **spends words**
  on a strict, concrete trigger: concrete verbs + the artifact ("when creating, editing, or
  reviewing …").
- **Manual** — invoked deliberately (e.g. a `/command`). No trigger bait; the description just
  states what it does so a human choosing from a list understands it. When the skill format can
  block model invocation (e.g. a `disable-model-invocation` flag), set it for Manual skills nothing
  invokes programmatically — the description then costs no standing context; when sibling skills
  must drive this one, keep it model-invocable and mark it "invoke manually only" in the
  description instead.
- **Self-Evident** — auto-loadable, but intent is obvious from a natural request (e.g. "fetch a
  ticket"). Trigger words ≈ the task name, so a short description routes correctly without a
  when/when-not clause.

Governing rule: **description tokens are justified only by trigger precision, never by summary.**
Compress *within* a type — but never starve a Mandatory trigger to save a few tokens.

Two sharpeners for the trigger wording:

- **One trigger per distinct path** through the skill. Phrasings collapse only when they lead the
  agent down the same path (true synonyms — "review a branch" / "check changes before merging");
  never collapse triggers that name different inputs or modes (a PR link vs a bare branch name).
- **Front-load the skill's leading word** (see compact-docs-writer). When the description carries
  the word the user's prompts and docs already use, the agent links that shared language to the
  skill and fires it more reliably.

Placement corollary: the body loads only after the skill triggers, when the choice is already
made — so keep when-to-use and routing cues in the description (read *before* the choice), never
in the body, where they steer nothing.

## Agnosticism

- **Agent-agnostic — hard rule.** Say "the agent" / "the session"; never vendor names ("Claude
  Code", "Claude", etc.). When improving a skill, flag and fix violations.
- **Project-agnostic — best-effort.** Default to generic wording. Couple to a project/framework/tool
  only when the skill's purpose requires it; when you must, keep it explicit and contained —
  declared up front or in a referenced doc — but skip a standalone declaration when the body already
  names the coupled artifacts throughout, since restating them only duplicates.
- **Tool-agnostic — follow the skill's stance.** When a skill operates over an external tool/service
  with interchangeable equivalents (design tools, trackers, cloud providers, …): if the skill is
  already agnostic — treating such tools as a class, naming specific ones only as examples —
  **preserve that**; new or edited content must stay generic, never hardcode a lone vendor as the
  sole path. Otherwise it's a nice-to-have: prefer generic wording, and when unsure whether to
  generalize or couple, ask the user.
- **Sibling-decoupled: track dependencies.** A skill may be installed with only its declared hard
  dependencies, not the whole toolkit, so a link to a sibling that isn't a dependency can dangle.
  Reference another skill only when it's a declared dependency or the link earns its keep
  operationally (e.g. an actionable next-step handoff); never add orientation prose that merely
  situates the skill among its siblings.

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

## Completion criteria — steps end checkable

When a skill encodes steps, end each on a **completion criterion** the agent can check — done vs
not-done — and make it exhaustive where a partial pass could look complete ("every modified file
accounted for", not "produce a summary"). A vague criterion is what makes an agent wrap up early;
sharpening it is the first and cheapest fix. Only when a criterion stays irreducibly fuzzy and
later steps still tempt rushing should those later steps move out of sight (a follow-on skill or a
disclosed doc).

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
   user to confirm or override. Version starts at `"1.0"`, or `"0.x"` when the author wants a trial
   period before declaring the skill stable — ask which. Improving: preserve existing fields, and
   flag any missing one.
4. **Draft** (create) or **improve** (existing): get the skill's content right — the rules it
   encodes, plus what improving adds (clarify where it's vague, under-specified, or missing a rule;
   loop back to intake if gaps surface) — compacting it through compact-docs-writer as you write,
   not in a later pass.
5. **Self-review** before presenting — terse yes/no, skill-specific (compact-docs-writer runs the
   compaction and removal-audit checks):
   - Wording agent-agnostic? Project coupling contained? Cross-references limited to declared
     dependencies or a real operational benefit?
   - Trigger type identified, and the description written to fit it? Test it four ways, reading
     only the description:
     - would an agent open the skill for the intended task?
     - would it skip a similar but unrelated task?
     - does it match what the skill now does (no stale claim the body contradicts)?
     - does it carry the skill's leading word itself — a paraphrase feels compliant but does no
       invocation work?

     Reword until all four hold.
   - Steps end on checkable, exhaustive completion criteria?
6. **Present & confirm** through compact-docs-writer (diff + word delta measured from the files,
   applied only on approval). In improve mode, **always put the version-bump decision to the
   user** — asking after applying is fine, but the edit stays incomplete until the version is
   settled; content approval (even given in advance) never covers it, so never let the question
   drop. If the version was already raised since the last commit, fold the change into that
   pending bump rather than bump again — and verify that pending state from git (version at HEAD
   vs working tree), never from session memory: the repo may have moved concurrently.
