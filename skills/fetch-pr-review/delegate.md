# Delegated fetch

How another skill runs fetch-pr-review in a subagent, and how the subagent behaves there.

## Caller

Say in one line what you spawn and for which input, then spawn one subagent briefed with: the PR
URL, the project's planning directory, every answer settled by an earlier relaunch, and the
instruction to run fetch-pr-review — the skill by name, or its `SKILL.md` path when the subagent
has no skill tool — under this file, passed by path. Nothing else from the session.

Its report is `done` or `blocked`:

- `blocked` → put the decision to the user as one question, recommending the subagent's pick, and
  relaunch with the answer added to the brief.
- `done` → confirm the file exists at the returned path and its Source line names the PR, then
  show the user the path and the unclear threads. Fidelity to the PR is the subagent's job —
  never re-fetch to check it.

## Subagent

`SKILL.md` holds, with two overrides:

- **No one to ask.** Apply what the brief settles. Decide the output directory and file name
  right after the PR metadata, before fetching the feedback, so a `blocked` costs one cheap call;
  only the refresh-or-round check (Later rounds) waits for the feedback. Any decision `SKILL.md`
  sends to the user — ambiguous input, the task's directory guess, the slug — and any obstacle (no
  matching MCP/CLI, auth) stops the run before anything is written: report `blocked`. Never a
  plausible guess, never a safe default. One exception: a thread with **unclear** status does not
  block — flag it `unclear` in the document, with what makes it unclear, for the triage to settle.
- **Report, don't hand off.** Return only: `done` with the project-relative path of the
  `.PR-REVIEW.md` and the list of threads flagged unclear (none → say so) — for a refresh, that
  nothing was written, with the latest existing file and the current head; or `blocked` with the
  decision or obstacle, its candidate answers, and your pick with why. No comment content, no
  next-step commands.
