---
name: prepare-prompt
description: Prepare a prompt that hands this session's work to a fresh agent session — to continue it, check it, or pick up what was left open. Use when asked for a prompt or brief for the next session.
license: MIT
metadata:
  version: "0.1"
---

# Prepare prompt

Write for a session holding only this text — no chat history, no memory of what was meant — and
make it as short as that reader allows: nothing it needs is cut for brevity, nothing else stays.
The reader is a fresh interactive session the user pastes it into; a subagent brief only when the
invocation asks for one, under the same rules.

## Input

The user's goal, in a line, plus this session. Draft at once; ask only what neither settles —
typically whether the next session may change things or only report — one question at a time,
with a recommended answer.

## Content

A suggested order, every part optional: a part is never filled to exist, and two lines are a
complete prompt when two lines cover the case.

1. **Situation** — what exists that the next session builds on, and what is open or was missed,
   each with its identifier (ticket URL, branch, commit, PR, task ids).
2. **Task and deliverable** — what to do, and in what form to report or produce it (a chat report
   with a given structure, a file, a code change).
3. **Latitude and boundaries** — what it may decide alone, when deviating is fine, what it must
   not touch (read-only, no git or tracker writes, files to ignore).
4. **Facts it cannot derive** — paths, the planning directory, docs to read, tool quirks with the
   workaround, a command that saves time.

The deliverable form and the write boundaries are the usual gaps: check whether the case needs
them.

What stays and what goes:

- A fact the next session builds on takes one line, never how it was reached. Anything it will
  redo anyway, and any narration of this session, goes.
- When its job is to check, verify or review something, this session's own conclusions about that
  thing go entirely — they would steer the check. When its job is to continue the work, the
  decisions it must build on stay, one line each.
- Point, never paste: what exists in a file or commit is referenced precisely (path and section,
  hash), never copied. Only what lives nowhere — a decision made in the chat, a tool quirk, a
  useful command — is written out.
- When an installed skill covers what the next session must do, the prompt opens with its slash
  command and the rest follows as its arguments (`/refine-ticket 1234 …`) — not a description of
  the procedure, nor prose like "run `/refine-ticket`", which cannot load a skill that blocks model
  invocation. Verify it exists first. A subagent cannot run a slash command: its brief names the
  skill to invoke instead, and a task whose skill blocks model invocation stays with an
  interactive session.

## Form

Plain imperative prose in paragraphs, no headings, bullets for lists. Agent-facing, so no
conversational voice. Print it as one fenced block, then a `---` line before any note to the
user; every revision reprints the whole block.

## Check before printing

- Every path, id and command in the prompt exists or works — verified by a read-only lookup, not
  remembered.
- Nothing narrates this session; for a checking job, nothing states this session's conclusion
  about the thing checked.
- A session holding only this text can act without asking what was meant.

Done when all three hold.

## Boundaries

- The printed prompt is the product: write no file unless asked.
