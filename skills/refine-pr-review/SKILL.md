---
name: refine-pr-review
description: Triage a fetched PR review with the user, comment by comment, drafting each reply and producing a REQUIREMENTS file for the accepted code changes. Takes the PR-REVIEW file produced by fetch-pr-review, or a PR URL. Invoke manually only.
license: MIT
metadata:
  version: "1.9"
---

# Refine PR review

The **Refine** phase for review feedback: turn a `.PR-REVIEW.md` (from /fetch-pr-review; ask if
the path is ambiguous) into user-settled per-comment verdicts, drafted replies, and a REQUIREMENTS
file covering the accepted code changes. Triage and replies are settled here; the plan and execute
phases see only code changes.

A PR URL instead: when the harness has subagents and fetch-pr-review is available
(`../fetch-pr-review/SKILL.md` beside this skill), a subagent fetches it first per its
[delegate.md](../fetch-pr-review/delegate.md) and the file it returns is the input. Not available
→ say so and ask for the fetched file; available but no subagents → hand off
`/fetch-pr-review <url>` to a fresh session and stop.

A trailing `head=<sha>` token (fetch-pr-review's refresh hand-off) is the head a refresh just
confirmed: Phase 1's moved-head check uses it in place of the file's `Head` line.

Its own `.PR-REVIEW.REQUIREMENTS.md` instead, once a blocking answer is in: run Phase 1's checkout
and remote-head check first — a checkout differing from the ANSWERS `Head`, or a dirty tree, is
reported and the user decides, never a branch switch; a moved PR head is reported with the
re-fetch offer and the user decides whether to finish this round first. Verdicts, replies and
Lessons stand as its `.PR-REVIEW.ANSWERS.md` records them. Apply the answer: every reply whose
described change it alters is re-drafted under Phase 1's voice rule, confirmed, and updated in
place; a verdict changes only as an explicit, user-confirmed exception to Phase 2's "Scope is
settled in Phase 1"; a lesson whose source rows are no longer all accepted is put to the user; no
row affected → the ANSWERS file is not rewritten. Then Phase 2 on that file, then Next step.

## Verdicts

- **address**: the change enters the requirements in full; the reply stays a canned one-liner
  ("fixed", "good catch, thanks").
- **partial**: part of the change is accepted into the requirements, and the reply explains what
  was done and what was kept and why.
- **push back**: no code change; the reply carries the reason.
- **no action**: no code change; a reply is optional (a question answered, an outdated concern the
  current code settles, an approval with no ask, the author's own comment) — when written, it is
  drafted and shown like any other.

Bot findings take `bot: included`, `bot: partial` (Notes say which part) or `bot: ignored`.

## Naming a comment

Never refer to a comment by index or position, anywhere — questions, batch lists, hand-off text.
Quote its opening words instead, truncated to the shortest unique prefix — the comment "the null
check here misses …". Always verbatim, never translated or corrected, so the quote can be searched
on the page. Only the ANSWERS table's own row numbers stay, for in-file cross-references.

## Phase 1 — triage every comment with the user

Before the first code check, compare the checkout with the PR-REVIEW head: a different commit or
branch, or a dirty tree, is reported and the user decides; never switch branches yourself. A PR
head that moved since the fetch (the remote compared with the file's `Head`, or with the
`head=<sha>` token when given) → offer a re-fetch before triage; a refresh (no new activity) keeps
the file, the checkout still compared with the current head, and a refresh the URL path's fetch
just reported needs no re-fetch. The URL path gets the same check — the subagent's fetch is seconds
old, the checkout is still the user's.

On a `-N` file, read the earlier rounds' ANSWERS first: a comment re-raising one already triaged
keeps its verdict and reply unless it brings evidence the earlier one lacked, and its Notes say
`kept from round K, row M`; a kept row's work and lessons stay with round K, never counted as
accepted below. An earlier round without ANSWERS was never triaged: its comments join this triage,
each row's Notes saying `joined from round K`, its status read from the latest `## Since round`
block listing it. A `-N` file with no touched thread (a Since block only) → say there is nothing
to triage, list the status changes, write no ANSWERS or REQUIREMENTS file, print no launch command,
stop. This round's ANSWERS file or REQUIREMENTS file already exists (and the REQUIREMENTS file is
not the input) → one question before triage, covering both: **update in place** (recommended —
existing rows stand, their verdicts and replies kept unless the user changes them or a comment
brings new evidence; only new or changed comments are triaged) or **start over** (every comment
re-triaged, both files replaced at write time). Never a second ANSWERS sheet; nothing overwritten
without this answer.

Read the code behind each comment first: verify its premise against the checkout, never judging
from the quoted hunk alone. Then form a recommendation — verdict, reasoning, and a draft reply for
every verdict but address: partial, push back, and a `no action` reply that answers or explains, a
courtesy reply on an outdated thread included. Before the first such draft in a round (even one
with no partial or push-back row), actually invoke `use-conversational-language` (Developer
conversations, author replies) and follow it; reciting its rules from memory does not count.
Not installed: plain prose, no dashes and no AI tells. Every reply other than address's canned
one-liner is shown to the user before it is written. Nothing is decided silently, and every
question to the user is worded via `explain-in-simple-language` when available, the draft reply it
carries excepted:

- **Contentious ones one at a time**: every comment recommended partial or push back, or
  uncertain, is its own question carrying recommendation, reasoning, and draft reply.
- **Obvious ones as one batch**: then list the comments recommended address or no action, each
  `no action` item with its draft reply, for a single confirmation; the user can pull any item out
  for individual discussion.

Per comment type:

- Open/active human threads → full triage.
- **Outdated** → code check first; when the concern is moot in the current code, recommend "no
  action, optional courtesy reply".
- **Unclear** (a status the fetch could not settle) → ask the user its status first, then triage
  it as that status.
- **Resolved** → no questions; table row marked "resolved earlier"; closed as won't-fix → Notes
  say so.
- Review verdict summaries and general comments → each actionable ask inside them is triaged like
  a thread. An `(author)` comment → no action unless it carries an ask worth tracking.
- Bot comments → never drafted replies; present the actionable findings as one batch
  include-or-ignore question. A bot thread flagged `human reply` is triaged as a human thread, the
  reply addressed to that person.

Phase 1 is complete only when every comment in the PR-REVIEW file has a user-confirmed verdict.
Write the ANSWERS file now, before Phase 2.

## Phase 2 — requirements via /refine-ticket

Treat the accepted work (address, the accepted part of each partial and bot: partial, and included
bot findings) as a settled-scope ticket and follow **/refine-ticket** (load and follow its
SKILL.md): code verification, blocking vs non-blocking, the REQUIREMENTS structure, location and
naming — all as written, with these overrides:

- Scope is settled in Phase 1 — never re-ask whether to address a comment; grilling covers only
  residual requirement-level gaps.
- The PR-REVIEW file is the local input, so the output lands next to it per its naming rule
  (`1234-task.PR-REVIEW.md` → `1234-task.PR-REVIEW.REQUIREMENTS.md`); later review rounds carry
  their suffix through (`…PR-REVIEW-2.REQUIREMENTS.md`).
- The existing-file question was asked before triage: never ask again at write time; update in
  place or replace as answered.
- A requirement's source tag is the comment's opening words and its `path:line` (threadless: its
  Location label), e.g. `("Validate both new option arguments", install.sh:88)` — never a row
  number.
- Nothing about replies or verdicts enters the REQUIREMENTS file.
- Ignore its hand-off commands, the blocking-question one included — this skill owns the hand-off.

When nothing is accepted (no address, partial, bot: included or bot: partial), skip this phase: no
REQUIREMENTS file, nothing to plan or execute.

## The ANSWERS file

`<input name>.ANSWERS.md` next to the input (`1234-task.PR-REVIEW.md` →
`1234-task.PR-REVIEW.ANSWERS.md`) — the user's copy-paste sheet and the durable record of what was
pushed back. Header: `# Answers: <PR title>`, then `> **Source** [<PR id>](<url>)`,
`> **Head** <sha>` (the head the verdicts were settled against), `> **Triaged** YYYY-MM-DD`; round
and requirements file follow from the file name. Then one table row per comment, resolved and bot
rows included for completeness:

| # | Original comment | Location | Verdict | Reply | Notes |

- **Original comment** — its opening words verbatim, truncated to the shortest unique prefix.
- **Location** — the thread's permalink from the PR-REVIEW file, with `path:line` as the readable
  label; a reply goes inside its thread, never as a top-level comment. A review summary or general
  comment has no thread: labelled `review summary` or `general comment`, linked to its permalink
  when the fetch has one, its reply a top-level comment quoting the ask.
- **Verdict** — `address` / `partial` / `push back` / `no action`, or `resolved earlier` /
  `bot: included` / `bot: partial` / `bot: ignored`.
- **Reply** — canned one-liner for address. Post-fix stance: written as if the accepted changes
  are already made ("did X, kept Y as is because …") — the sheet is pasted after the fixes land. A
  reply too long for a cell goes below the table under a `## Reply <row #>` heading that opens with
  the original comment quoted in full as a blockquote, so each reply is checkable against its
  question without scrolling back to the table.
- **Notes** — the reasoning in a few words, for future review rounds.

## Lessons

During Phase 1, note accepted comments (address, the accepted part of partial, bot: included, bot:
partial) whose lesson generalizes — would a fresh agent on another task here plausibly repeat the
mistake? A one-off slip fails; a convention or recurring pattern passes. After Phase 2, present
them as one batch for the user to strike or add to, each phrased as the general rule, not the
incident ("Mock external HTTP in unit tests", not "the null check on line 42"). Append the
survivors as a `## Lessons` section at the end of the ANSWERS file, one line each with its source
row numbers; none → no section.

## Boundaries

- **Never touch the PR**: no posting, replying, resolving, or voting — file in, files out.
- No implementation, no plan. The only files written: the ANSWERS and REQUIREMENTS files.

## Next step

State the output paths (project-relative). Remind the user the ANSWERS file is theirs to post
manually once the fixes land. No REQUIREMENTS file → no launch command, only that reminder (and
the self-improve line below when Lessons were written). While the REQUIREMENTS file holds a
**blocking** Open questions entry, print no execute or plan command, only who must answer it and
the command for once the answer is in: `/refine-pr-review <requirements-file>`. Otherwise hand off
by the size of the accepted change set, leading with your recommendation but giving the options
as single copy-pasteable launch commands (vendor-agnostic — `claude` below is only the example).
The recommendation names only options printed below: without create-implementation-plan, a
substantial change set is recommended to harden first (when available), else to execute directly.

Small, mechanical change set — execute directly:

```
claude --name execute-review-<slug> "Apply <requirements-file>, then run the project's validation (lint, tests, build)"
```

`/create-implementation-plan` available — substantial change set (cross-file rework, design
decisions), plan first:

```
claude --name create-plan-<slug> "/create-implementation-plan <requirements-file>"
```

`/harden-artifact` available — harden the requirements first, recommended for a substantial change
set:

```
claude --name harden-requirements-<slug> "/harden-artifact <requirements-file>"
```

Lessons written and `/self-improve` available — persist them after the execute session, since a
mechanical lesson may edit a lint config or CI job it also touches:

```
claude --name self-improve-<slug> "/self-improve Persist the lessons listed under Lessons in <answers-file>"
```

Then offer the alternative — clearing the current session (vendor-agnostic — `/clear` is only the
example) and running the chosen prompt directly; the same gates apply to the bare prompts.
