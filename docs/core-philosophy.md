# agent-toolkit: core philosophy

The pillars behind agent-toolkit and the way of working it encodes — the conceptual source of
truth. Feed it to any agent that must represent the project faithfully: creating or improving
skills, brainstorming, website copy, docs, talks, articles.

## What agent-toolkit is

A minimalistic, MIT-licensed collection of generic skills and rules for AI coding agents (catalog
in the [README](../README.md)).

- **Project-agnostic**: any codebase, tech stack, or ticket tracker. Project-specific skills can
  wrap the generic ones, never the other way around.
- **Agent-agnostic**: works with Claude Code, OpenCode, GitHub Copilot, Codex, Kimi and others.
  One canonical install location (`~/.agents`), symlinked into each agent's directory — take
  everything, or just the pieces that fit.
- **Born from necessity**: built while freelancing across projects and teams with very different
  levels of AI adoption, where tooling that only works in one environment is useless. Versatility
  is not a feature, it is the founding constraint. Each skill is a repetitive piece of real daily
  work, converted into automation.

## Pillar 1: keep the context lean

A full context window makes a dumb agent. A session's early tokens get sharp attention (the
"Smart Zone"); as the window fills, reasoning degrades (the "Dumb Zone") — and much of the useful
range is often consumed before the user even types: global config files, skill descriptions, MCP
server instructions, auto-loaded memory.

In the toolkit:

- Every skill and doc is written with the least text possible while losing zero information
  (`compact-skill-creator`, `compact-docs-writer`).
- Skills are single-purpose: each loads only the instructions its task needs, and small skills
  compose into larger workflows.
- Docs follow progressive disclosure: a lean always-loaded index referencing detail docs that are
  read only when the task needs them.
- `/context-checkup` audits what auto-loads at startup, estimates the token cost per source, and
  proposes lean, reversible trims. Measure, never guess.
- `/memory-doctor` treats agent memory as an inbox, not a filing cabinet: every block gets
  relocated to a proper home, archived, or consciously kept. Nothing stays in memory by default.

## Pillar 2: offload to files, pick up fresh

Long sessions degrade. Instead of one endless conversation, work is split into phases, each phase
writes its result to a self-contained markdown artifact, and a fresh session picks the artifact up
with a clean context.

In the toolkit:

- The Refine-Plan-Act (RPA) workflow: `TICKET.md` (fetch) becomes `REQUIREMENTS.md` (refine, the
  WHAT) becomes `PLAN.md` (plan, the HOW) becomes code (act). Each transition is a context reset;
  only the act phase touches source code. Trivial, well-defined tasks may skip phases — the
  artifacts are a tool, not a ceremony.
- Artifacts are self-contained: the executor of a plan re-derives nothing. All the thinking lives
  in the file.
- The thinking is saved separately from the code: bad output is cheap to throw away, because the
  plan survives and can be tweaked and re-executed. Once the thinking is externalized, execution
  becomes a commodity — even delegable to a cheaper model.
- Document-only phases of different tasks can run in parallel sessions without conflicts; code
  changes stay sequential (or in git worktrees).
- Fresh eyes validate: a clean session can check any artifact against its predecessor —
  requirements against ticket, implementation against plan (`fresh-eyes-review`,
  `check-ticket-implementation`).
- Artifacts are plain markdown: any human or agent can read, review, share or hand them off, and
  they live on after the task ships — as PR descriptions, ticket comments, documentation. This is
  what makes the workflow team-friendly regardless of how much AI the team uses.

## Pillar 3: human in the loop

The agent recommends, the human decides. Skills are primarily user-invoked: nothing activates
behind the user's back.

In the toolkit:

- The golden rule: never guess, ask. When requirements are ambiguous, the agent asks one question
  at a time, always paired with a recommended answer (the "grilling" technique). Questions
  answerable from the codebase go to the codebase, only genuine decisions go to the human.
- Suggest, never apply: skills that modify things (memory, docs, other skills, trims to config)
  present a diff or proposal and wait for approval.
- Predictability over magic: the user always knows what loaded into the context and why — the
  deliberate opposite of auto-activating frameworks. Trade-off accepted: the user must know their
  toolkit, starting with installing only what they have vetted.
- Early human review: wrong assumptions die in `REQUIREMENTS.md`, not in a 40-file diff.

## Pillar 4: agents learn from their own mistakes

Every correction is a signal. If the human had to fix or redirect the agent, the lesson must be
persisted somewhere durable, versioned, and shared, or it will be repeated.

In the toolkit:

- `/self-improve` locates the governing skill, rule or doc behind a mistake and proposes a compact
  edit that would have prevented it.
- The `self-improve-on-correction` rule closes the loop by offering this automatically whenever
  the user corrects the agent; `/refine-pr-review` does the same for the durable lessons in
  accepted reviewer feedback.
- Lessons get promoted out of private memory into homes the team controls: project docs, skills,
  rules. Individual corrections become collective improvements.
- Result: the toolkit and its host projects genuinely improve every day of use.

## Pillar 5: generic beats specific

Every artifact in the toolkit must survive a change of project, agent, team, or tracker.

In the toolkit:

- Skills reference capabilities, not products: "the ticket tracker MCP", not a hardcoded Jira
  integration.
- Rules are decoupled from skills and always opt-in, because they are always-on and opinionated
  (e.g. `git-read-only-by-default`).
- Human-facing output must read human: PR replies and commit messages sound like a colleague wrote
  them (`use-conversational-language`, enforced by the `write-realistic-texts` rule), because in
  mixed teams trust depends on it.

## The litmus test

Apply to any new or edited skill, rule, or doc — a "no" on any line means it is not ready:

1. **Lean**: is every sentence load-bearing, and does it load into context only when its task
   needs it?
2. **Offloaded**: can a fresh session pick up the artifact it produces without asking what was
   meant?
3. **Human in the loop**: does it recommend and wait, rather than decide behind the user's back?
4. **Self-improving**: does the lesson from a correction get a durable, versioned home?
5. **Generic**: does it survive a change of project, agent, team, and tracker?

## One-paragraph summary

agent-toolkit is the opposite of an auto-magic framework: a small set of sharp, user-invoked
tools built on five habits — lean context, file-based phase handoffs, human in the loop,
persistent self-improvement, generic beats specific — so that an engineer's workflow stays
portable across every project, agent and team, and gets a little better every day.

## Further reading

The pillars in long form:

- [How I use AI agents to solve programming tasks daily](https://medium.com/engineering-in-the-age-of-ai/how-i-use-ai-agents-to-solve-programming-tasks-daily-2a68a5828b8e) — the daily workflow end to end.
- [The Refine-Plan-Act pattern for agentic AI coding](https://medium.com/engineering-in-the-age-of-ai/the-refine-plan-act-pattern-for-agentic-ai-coding-59ee013e4427) — pillar 2 in depth.
- [Keep your AI agent's context window sharp](https://medium.com/engineering-in-the-age-of-ai/keep-your-ai-agents-context-window-sharp-7255d83a8949) — pillar 1 in depth.
- [My approach to agentic skills](https://medium.com/engineering-in-the-age-of-ai/my-approach-to-agentic-skills-e08dc6c0d1cd) — the pillars applied to skill design.
- [Keep your AI agents' memory clean and organized with memory-doctor](https://medium.com/engineering-in-the-age-of-ai/keep-your-ai-agents-memory-clean-and-organized-with-memory-doctor-a79f7174f257) — memory hygiene, pillars 1 and 4.

Skills in-depth and relevant miscellaneous:

- [How to make AI write like a human actually would](https://medium.com/engineering-in-the-age-of-ai/how-to-use-ai-to-generate-texts-that-sound-like-a-human-would-actually-write-them-c7eef78e0b42) — article dedicated to the /use-conversational-language skill

- [Let AI speed up both sides of your code reviews, while you stay in full control](https://medium.com/engineering-in-the-age-of-ai/let-ai-speed-up-both-sides-of-your-code-reviews-while-you-stay-in-full-control-3b059506ef39) — article dedicated to the PR review skills

- [The Missing Step in Agentic Coding: The Handover](https://medium.com/engineering-in-the-age-of-ai/the-missing-step-in-agentic-coding-the-handover-d1963c3d2c1d) — article dedicated to the /handover skill

- [More powerful AI reviews with fresh eyes](https://medium.com/engineering-in-the-age-of-ai/more-powerful-ai-reviews-with-fresh-eyes-bfad221748c0)
