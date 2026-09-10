---
name: handover
description: Use when handing finished work over to code review — writing a PR description or packaging a change for review by a human, an agent, or both.
license: MIT
metadata:
  version: "0.6"
---

# Handover

Package a finished change so its reviewers never reconstruct intent from the diff. Write for a
reviewer holding the diff and nothing else — no planning docs, no session, no knowledge that
either exists.

## Resolve the task

The input is any partial reference — ticket id, slug, a planning artifact's path — or nothing,
meaning the session's task; in a fresh session, infer it from branch name and recent commits.
Resolve it to the task's **planning home**: its `<id>-<slug>/` directory in the project's planning
directory, or its flat `<id>-<slug>.*` files in a shared family directory. One clear match →
proceed, stating the home and artifacts found. Inferred, or several candidates (`-vN`, …) →
confirm first. An explicit reference matching nothing local → stop and ask; never guess.

## Gather

Read these, skipping what doesn't exist:

1. **Task artifacts** — every `<id>-<slug>*.md` in the planning home: ticket, requirements, plan,
   decisions log, prior review and handover rounds, whatever else matches.
2. **Related tickets** — one hop only: parent (climbing higher only past thin containers), direct
   predecessors/successors, explicit relations, family-directory siblings; never expand their own
   relations. Local `.TICKET.md`s first; fetch from the tracker only when a relation has no local
   file and looks load-bearing for a why — in doubt whether to fetch, ask.
3. **The session**, when it produced the change: decisions, pivots, constraints.
4. **The diff** against the target, plus commit subjects.

An earlier artifact — a ticket review, a prior round — counts only where nothing later settled the
point.

Each source once, no deeper than the artifact needs: skim the diff whole, deep-read only the files
you will name in the *Review guide*, and never rebuild history commit by commit — which commit
changed what is the diff's job, not yours.

Then match the plan's steps and acceptance criteria against the diff both ways — planned but
absent, present but unplanned. Done when every source is read or confirmed absent and every planned
item is matched.

## Source every claim

State a "why", or any other claim about the change, only where a source gives it. Silence is not a
source: never infer a fact from what the diff and docs leave unsaid ("untested so far", "nobody
calls this"). A deviation nothing explains is asked of the author once; unanswered or unaskable, it
ships flagged in plain words ("nothing records why — worth confirming"), since it may be an
unintentional gap rather than a decision. Sourcing is your gate, not the reviewer's reading: it
decides what you may write, and never appears in the text. When not sure, always ask. Never guess.

## The artifact

`<slug>.HANDOVER.md` in the planning home; already taken → `<slug>.HANDOVER-2.md`, `-3`, … —
never overwrite. No planning home → present the content and ask where to save it. Its body is
paste-ready as the PR description, and stands alone:

- **Mention only what the reviewer can open** — a tracker URL, or a file you verified is committed
  on the branch. Everything else — planning docs, decisions log, session, commit hashes — is
  neither linked nor named: write what it says ("this was meant to …"), never where it says it.
  A colleague's clarification is stated as what it settled, grounded in something openable ("the
  goal is X, which <ticket URL> needs"); naming the colleague is the last resort.
- **Related tickets go unmentioned** unless a why depends on one ("built this way to prepare
  for <X>") — then cite its tracker URL.
- **Under a screen**, ~400 words; the caps below are limits, not targets.
- **Never hard-wrap**: forges (e.g. GitHub) render newlines in PR bodies as line breaks — one
  line per paragraph or bullet.
- **Plain reviewer-facing wording**, never this skill's vocabulary. Before drafting, actually
  invoke use-conversational-language — reciting its rules from memory does not count.

Sections, skipped only when truly empty:

1. **What and why** — 2–3 lines.
2. **Decisions worth knowing** — at most 5 lines, each: what was chosen or what departs from the
   plan, its why or the missing-why flag, and where in the code to see it.
3. **Review guide** — the few files where judgment matters and why; the rest named as mechanical.
4. **Known gaps** — at most 3 shortcomings, assumptions or open questions the sources establish;
   none → omit the section, never manufacture one.

Done when every section is filled or knowingly skipped, every claim traces to a source, and nothing
in the text points at something the reviewer cannot open.

## Boundaries

- Modify no source files; the handover doc is the only file written.
- Never push, or open/comment on a PR — publishing is the user's explicit call.
