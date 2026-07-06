---
name: refine-pr-review
description: Triage a fetched PR review with the user, comment by comment — address, partial, or push back — drafting each reply and producing a REQUIREMENTS file for the accepted code changes. Takes the PR-REVIEW file produced by fetch-pr-review. Invoke manually only.
license: MIT
metadata:
  author: Francesco Borzì
  version: "0.1"
---

# Refine PR review

The **Refine** phase for review feedback: turn a `.PR-REVIEW.md` (from /fetch-pr-review; ask if
the path is ambiguous) into user-settled per-comment verdicts, drafted replies, and a REQUIREMENTS
file covering the accepted code changes. Triage and replies are settled here; the plan and execute
phases see only code changes.

## Verdicts

- **address**: the change enters the requirements in full; the reply stays a canned one-liner
  ("fixed", "good catch, thanks").
- **partial**: part of the change is accepted into the requirements, and the reply explains what
  was done and what was kept and why.
- **push back**: no code change; the reply carries the reason.

## Phase 1 — triage every comment with the user

Read the code behind each comment first: verify its premise against the current codebase, never
judging from the quoted hunk alone. Then form a recommendation — verdict, reasoning, and (for
partial and push back) a draft reply. Nothing is decided silently:

- **Contentious ones one at a time**: every comment recommended partial or push back, or
  uncertain, is its own question carrying recommendation, reasoning, and draft reply.
- **Obvious ones as one batch**: then list the comments recommended address or no action for a
  single confirmation; the user can pull any item out for individual discussion.

Per comment type:

- Open/active human threads → full triage.
- **Outdated** → code check first; when the concern is moot in the current code, recommend "no
  action, optional courtesy reply".
- **Resolved** → no questions; table row marked "resolved earlier".
- Review verdict summaries and general comments → each actionable ask inside them is triaged like
  a thread.
- Bot comments → never drafted replies; present the actionable findings as one batch
  include-or-ignore question.

Phase 1 is complete only when every comment in the PR-REVIEW file has a user-confirmed verdict.

## Phase 2 — requirements via /refine-ticket

Treat the accepted work (address, the accepted part of each partial, and included bot findings) as
a settled-scope ticket and follow **/refine-ticket** (load and follow its SKILL.md): code
verification, blocking vs non-blocking, the REQUIREMENTS structure, location and naming — all as
written, with these overrides:

- Scope is settled in Phase 1 — never re-ask whether to address a comment; grilling covers only
  residual requirement-level gaps.
- The PR-REVIEW file is the local input, so the output lands next to it per its naming rule
  (`1234-task.PR-REVIEW.md` → `1234-task.PR-REVIEW.REQUIREMENTS.md`); later review rounds carry
  their suffix through (`…PR-REVIEW-2.REQUIREMENTS.md`).
- Nothing about replies or verdicts enters the REQUIREMENTS file.
- Ignore its closing hand-off instructions — this skill owns the hand-off.

When every verdict is push back, skip this phase: no REQUIREMENTS file, nothing to plan or execute.

## The ANSWERS file

`<input name>.ANSWERS.md` next to the input (`1234-task.PR-REVIEW.md` →
`1234-task.PR-REVIEW.ANSWERS.md`) — the user's copy-paste sheet and the durable record of what was
pushed back. One table row per comment, resolved and bot rows included for completeness:

| # | Location | Verdict | Reply | Notes |

- **Location** — `path:line` / thread anchor from the PR-REVIEW file, so each reply is easy to
  place on the platform.
- **Verdict** — `address` / `partial` / `push back`, or `no action` / `resolved earlier` /
  `bot: ignored` / `bot: included`.
- **Reply** — voiced per **/use-conversational-language** (Developer conversations, author replies);
  canned one-liner for address. Post-fix stance: written as if the accepted changes are already
  made ("did X, kept Y as is because …") — the sheet is pasted after the fixes land. A reply too
  long for a cell goes below the table, referenced by its row number.
- **Notes** — the reasoning in a few words, for future review rounds.

## Boundaries

- **Never touch the PR**: no posting, replying, resolving, or voting — file in, files out.
- No implementation, no plan. The only files written: the ANSWERS and REQUIREMENTS files.

## Next step

State the output paths (project-relative). Remind the user the ANSWERS file is theirs to post
manually once the fixes land. Then hand off by the size of the accepted change set, leading with
your recommendation but giving both options as single copy-pasteable launch commands
(vendor-agnostic — `claude` below is only the example):

Small, mechanical change set — execute directly:

```
claude --name execute-review-<slug> "Apply <path>.PR-REVIEW.REQUIREMENTS.md, then run the project's validation (lint, tests, build)"
```

Substantial change set (cross-file rework, design decisions) — plan first:

```
claude --name create-plan-<slug> "/create-implementation-plan <path>.PR-REVIEW.REQUIREMENTS.md"
```

Then offer the alternative — clearing the current session (vendor-agnostic — `/clear` is only the
example) and running the chosen prompt directly.
