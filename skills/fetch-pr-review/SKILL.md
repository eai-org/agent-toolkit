---
name: fetch-pr-review
description: Fetch all reviewer comments from a pull request URL (GitHub, Azure DevOps, …) and save them as a self-contained markdown PR-REVIEW file in the task's planning directory. Fetch only — no fixing or replying.
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.2"
---

# PR review fetcher

**Fetch only** — capture the review feedback left on a pull request; never fix code, reply, or
judge the comments. Output is a self-contained `.PR-REVIEW.md` a fresh session can pick up and act
on (e.g. via `/refine-ticket`).

## Source & access

Identify the platform from the PR URL (host shape) and fetch through the matching MCP server or
CLI — e.g. **GitHub MCP / `gh`** for GitHub PRs, **Azure DevOps MCP** for ADO pull requests. Use
whichever equivalent tools are connected; tool name prefixes vary by config. If the input is
ambiguous, or no matching MCP/CLI is available, ask the user / stop — don't guess.

## Golden rule: never assume — ask

Every uncertainty is confirmed with the user before proceeding: a thread's resolved status, the
planning directory, the slug, anything ambiguous in between. A plausible guess is a question, not
an answer.

## Your task

1. **Resolve the input.** Accept a full PR URL; extract repo/project and PR id. If unrecognizable,
   ask.
2. **Fetch the PR metadata** — title, description, source/target branch, state, author, linked
   ticket/work item — and **all feedback**:
   - inline review threads (file, line, code context, full reply chain);
   - top-level review verdicts (approve / request changes / …) with their summary text;
   - general conversation comments;
   - bot comments (CI, linters, coverage, …) — captured too, but grouped separately from human
     feedback.
3. **Determine each thread's status** (see Status flags).
4. **Decide the output directory** — the planning directory of the task the PR belongs to,
   following the project's/user's convention for where plans live. Guess the existing
   `<id>-<slug>/` subdirectory from PR context (linked ticket id, branch name, PR title) and
   **confirm the guess with the user**; when not sure, always ask. If no matching directory
   exists, propose a new `<id>-<slug>` (ticket id prefix when bound to one, kebab-case slug from
   the PR title), confirm, and create it.
5. **Pick the file name** — `<slug>.PR-REVIEW.md`, where `<slug>` is the planning directory name
   (e.g. `1234-some-task.PR-REVIEW.md`). If it already exists and this is a new review round,
   write `<slug>.PR-REVIEW-2.md`, `-3`, … — **never overwrite**; history per round is kept on
   purpose.
6. **Write the document** (see structure below).
7. **Print the result** — project-relative paths and the next-step line.

## Status flags

Capture **every** comment, resolved or not, with its state from the platform's own signal (e.g.
GitHub thread resolution, ADO thread status):

- **Open / active** → actionable; no flag needed.
- **Resolved** (closed, fixed, won't fix, …) → keep it, marked **resolved**, with the platform's
  original status verbatim — `wontFix` is resolved but carries different intent than `fixed`.
- **Outdated** (anchored to code later commits changed) → distinct **outdated** flag, never merged
  into resolved: the code moved, but **the concern may still be valid** — say so in the document.
- **Unclear** — the platform gives no clear signal, or the thread reads ambiguous (e.g. a reply
  says "done" but the thread is still open) → **ask the user** how to mark it; never decide alone.

## Document structure

Must stand on its own: a fresh session with no access to the PR must be able to locate every spot
in the code and understand every piece of feedback without re-fetching.

```markdown
# PR review: <title>

> **Source** [<PR id>](<url>)
> **Branch** <source> → <target>
> **State** {open/merged/…}
> **Author** {display name}
> **Linked ticket** [<id>](<url>) — omit if none
> **Fetched** {today YYYY-MM-DD}

## Review verdicts        — one per reviewer: verdict + summary text
## Inline threads         — one ### per thread: `path:line`, quoted code context/diff hunk,
                            comments oldest first as <author> — <date>, status flag
## General comments       — non-inline human conversation, oldest first
## Bot comments           — automated feedback, grouped by bot
```

Omit empty sections. Quote file paths, code, identifiers, and user-facing strings **verbatim** —
never alter or translate them.

## Boundaries

- The PR stays untouched — fetching is **read-only**: no replies, no resolving threads, no votes,
  approvals, or edits.
- **Do not** fix, analyze, or triage the feedback — capture and flag only.
- The only files you create: the `.PR-REVIEW.md` (and its planning directory if new).

## Next step

State clearly when done, using **project-relative paths**. List any thread whose status needed a
user decision and how it was marked. Then hand off the next phase as a
**single copy-pasteable launch command** — session name and prompt combined, so one paste starts the
session. Use the launch syntax of the agent tool in use (vendor-agnostic — `claude` below is only
the example), naming the session `refine-<slug>`:

```
claude --name refine-<slug> "/refine-ticket <output-dir>/<slug>.PR-REVIEW.md"
```
