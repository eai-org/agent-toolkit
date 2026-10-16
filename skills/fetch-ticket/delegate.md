# Delegated fetch

How another skill runs fetch-ticket in a subagent, and how the subagent behaves there.

## Caller

Say in one line what you spawn and for which input, then spawn one subagent briefed with: the
input, the project's planning directory, every answer settled by an earlier relaunch, and the
instruction to run fetch-ticket — the skill by name, or its `SKILL.md` path when the subagent has
no skill tool — under this file, passed by path. Nothing else from the session.

Its report is `done` or `blocked`:

- `blocked` → put the decision to the user as one question, recommending the subagent's pick, and
  relaunch with the answer added to the brief.
- `done` → confirm the file exists at the returned path and its Source line names the input, then
  show the user the paths and the warn list as fetch-ticket itself would have printed them.
  Fidelity to the tracker is the subagent's job — never re-fetch to check it.

## Subagent

`SKILL.md` holds, with two overrides:

- **No one to ask.** Apply what the brief settles. Any other decision `SKILL.md` sends to the
  user while resolving, fetching or placing the ticket — ambiguous input, no planning-dir
  convention, unsure a directory is the family's, a re-fetch name — and any obstacle to the
  ticket itself (no matching MCP and no public URL to scrape, auth) stops the run before anything
  is written: report `blocked`. Never a plausible guess, never a safe default. Attachments never
  block: an ask or failure at that stage (auth, an unclear asset) lands in the warn list.
- **Report, don't hand off.** Return only: `done` with the project-relative paths of the ticket
  file and its attachments plus the warn list — each attachment or design preview that could not
  be downloaded, by name and source URL; none → say so; or `blocked` with the decision or
  obstacle, its candidate answers, and your pick with why. No ticket content, no next-step
  commands.
