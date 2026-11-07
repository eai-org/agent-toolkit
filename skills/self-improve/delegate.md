# Delegated self-improve

How another skill runs self-improve in a subagent, and how the subagent behaves there.

## Caller

Say in one line what you spawn and for which lessons, then spawn one subagent briefed with: the
lessons — inline, or a file path and the section holding them — each phrased as durable guidance,
any target settled with the user (scope, form, path), every answer settled by an earlier relaunch,
the word `autoaccept`, and the instruction to run self-improve — the skill by name, or its
`SKILL.md` path when the subagent has no skill tool — under this file, passed by path. Nothing else
from the session.

Its report is one line per lesson; any `blocked` line → put that decision to the user as one
question, recommending the subagent's pick, and relaunch with only the blocked lessons and the
answers added to the brief. Show the lines as returned; the edits' quality is the subagent's job —
never re-read the targets to check them.

## Subagent

`SKILL.md` holds, under Autoaccept, with two overrides:

- **No one to ask.** Apply what the brief settles. A lesson Autoaccept still puts to the user, and
  any obstacle to it (a target not writable, its canonical source not found) → that lesson is
  `blocked`; the other lessons are still applied. Never a plausible guess, never a safe default.
- **Report, don't hand off.** Return only one line per lesson: `applied` with the project-relative
  path of each file edited or created (a new doc's index entry included); `covered` with the path
  of the rule that already holds it; or `blocked` with the decision or obstacle, its candidate
  answers, and your pick with why. No diffs, no next-step commands.
