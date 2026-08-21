---
name: extract-pr-review-rules
description: Extract a repository's inline PR review comments into a per-reviewer pr-review-rules doc for the project's review skills, resuming from the last run's checkpoint.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "0.1"
---

# Extract PR review rules

Mine the conventions a repository's reviewers enforce in their inline PR review comments into one
governing doc the project's review skills run as a checklist. Re-runnable: each run resumes from
the last one's checkpoint, fetching only newer comments.

Invocation: `/extract-pr-review-rules <repo-url>`

## 1. Resolve the target

Identify the forge from the repo URL and work through whatever MCP or CLI is connected for it
(GitHub → `gh`). Unrecognized URL, or nothing connected → ask.

The URL says where the comments come from; the doc lands in the **current** project, under its
governing-docs convention, defaulting to `.agents/docs/pr-review-rules.md`. Already there → read
it: its checkpoint and standing rules make this a **refresh**. Absent → **first run**, no
checkpoint, whole history in scope.

Done when the forge tooling, the doc path, and the checkpoint (a timestamp, or none) are settled.

## 2. Fetch to disk

Page the repo's inline review-comment feed across all PRs, open and closed, **straight to a file**
in the session's scratch dir — never through the model, which truncates silently. On a refresh,
filter by the checkpoint so only new comments come down:

```bash
gh api --paginate "repos/<owner>/<repo>/pulls/comments?per_page=100&since=<checkpoint>" \
  > "$SCRATCH/comments.json"
```

Record the time the fetch **started** as the next checkpoint — not the newest comment's timestamp,
which would skip anything posted while the run was working.

Then, still on disk, drop bots and deleted accounts, tally comments per author, and split the file
into one per author. Nothing new to process → say so, leave the doc untouched, and stop.

Done when each author's file exists, the tallies sum to the fetched total, and the new checkpoint
is recorded.

## 3. Extract, one subagent per reviewer

One isolated subagent per author, in parallel, each reading **only** that author's file so the raw
comments never reach this session. No subagents in the runtime → work the files here one at a
time. Prompt each with:

- the author's name, handle, and comment-file path;
- **the bar** — a rule is a convention that outlives the line it was written on ("always use
  `inject()`", "never leave a TODO without a ticket"). A comment fixing only its own spot ("this
  import is unused", "rename this to `x`") is dropped unless it states the underlying rule. One
  comment is enough to found a rule; recurrence is not required;
- **the shape** — return that reviewer's section and nothing else: `### <topic>` sub-headings
  derived from their own comments, never a fixed taxonomy; one bullet per rule, imperative and on
  one line, closing with its source-comment links, newest first, capped at 5;
- read-only.

Done when every author has returned a section or reported no rule clearing the bar.

## 4. Merge — refresh only

Each extracted rule, against the rules already in the doc:

- **Reinforces** one — same rule, fresh evidence → append its links, keep the newest 5. Silent.
- **New** → add it under the reviewer's fitting topic. Silent.
- **Contradicts** one — the team moved on → the newer wins, but never silently: show the standing
  rule, the comment overturning it with author and date, and the proposed replacement; apply on
  approval, keep the old rule if the user prefers.

Rules whose comments this run didn't re-fetch stay exactly as they are; never rewrite the doc from
a partial fetch.

Done when every extracted rule is appended, added, or settled with the user.

## 5. Write the doc

Reviewers ordered by comment count, descending; one with no surviving rule is left out.

```markdown
# PR review rules

Conventions each reviewer of [<owner>/<repo>](<repo-url>) enforces, extracted from their inline
pull-request review comments. Each rule links the comments it came from.

## Checkpoint

- Generated <YYYY-MM-DD>
- Covers <N> review comments up to <ISO timestamp>, bots excluded
- Refresh with `/extract-pr-review-rules <repo-url>`

## Reviewers

- [<name>](#<anchor>) — `<handle>`, <N> comments

## <name>

`<handle>` · <N> review comments

### <topic>

- <rule> ([#<comment-id>](<comment-url>), …)
```

Done when every rule from steps 3–4 is in the file and the checkpoint line carries this run's
timestamp.

## 6. Index and close

Review skills reach the doc through the project's agent entry file: unless `AGENTS.md`/`CLAUDE.md`
already links it, propose a one-line index entry with a read-when hook — `- [PR review
rules](.agents/docs/pr-review-rules.md) — read when reviewing a change` — and add it on approval.

Close with the doc's project-relative path, the counts (comments processed, rules added,
reinforced, superseded), and the new checkpoint.

Done when the doc is indexed or the user declined, and all three are printed.

## Boundaries

- **Read-only on the forge** — no comments, replies, resolutions, or votes.
- Files written: the rules doc, the entry-file index line, and scratch files. Never commit.
