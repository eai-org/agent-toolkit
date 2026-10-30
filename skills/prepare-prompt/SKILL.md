---
name: prepare-prompt
description: Prepare a prompt that hands this session's work to a fresh agent session — to continue it, check it, or pick up what was left open. Use when asked for a prompt or brief for the next session.
license: MIT
metadata:
  version: "1.1"
---

# Prepare prompt

Write for a session holding only this text — no chat history, no memory of what was meant — and
make it as short as that reader allows: nothing it needs is cut for brevity, nothing else stays.
The reader is a fresh interactive session the user pastes it into; a subagent brief only when the
invocation asks for one, under the same rules.

## Input

The user's goal, in a line, plus this session. Draft at once; ask only what neither settles, one
question at a time, with a recommended answer.

## Content

A suggested order, every part optional: a part is never filled to exist, and two lines are a
complete prompt when two lines cover the case.

1. **Situation** — what exists that the next session builds on, and what is open or was missed,
   each with its identifier (ticket URL, branch, commit, PR, task ids).
2. **Task and deliverable** — what to do, in what form to report or produce it (a chat report
   with a given structure, a file, a code change) and, when the work continues, the check that
   says it is done (a command, a criterion, a file to exist).
3. **Latitude and boundaries** — what it may decide alone, when deviating is fine, what it must
   not touch (read-only, no git or tracker writes, files to ignore).
4. **Facts it cannot derive** — paths, the planning directory, docs to read, tool quirks with the
   workaround (even one a failed try revealed), a command that saves time. When it continues the
   work, picking up what was left open included, also each approach this or an earlier session tried
   and ruled out, one line with the reason; none when its job is to check, verify or review, even if
   it continues the work afterwards, since they would steer the check.

The deliverable form and the write boundaries are the usual gaps: check whether the case needs
them.

What stays and what goes:

- A fact the next session builds on takes one line, never how it was reached. Anything it will
  redo anyway, and any narration of this session, goes. A ruled-out approach (part 4) is a fact in
  its own right, not narration, and may share the line of the decision that replaced it
  ("X, not Y: reason").
- When its job is to check, verify or review something, this session's own conclusions about that
  thing go entirely — they would steer the check. When its job is to continue the work, the
  decisions it must build on stay, one line each.
- Point, never paste: what exists in a file or commit is referenced precisely (path and section,
  hash), never copied. Only what lives nowhere — a decision made in the chat, a tool quirk, a
  useful command — is written out. Never a credential: one the next session needs is named by
  where it lives (env var, config path); one that lives nowhere, such as a key pasted in chat, is
  left out and the prompt says to get it from the user.
- When an installed skill covers what the next session must do, the prompt opens with its slash
  command and the rest follows as its arguments (`/refine-ticket 1234 …`) — not a description of
  the procedure, nor prose like "run `/refine-ticket`", which cannot load a skill that blocks model
  invocation. Verify it exists first. A subagent cannot run a slash command: its brief names the
  skill to invoke instead, and a task whose skill blocks model invocation stays with an
  interactive session.

## Form

Plain imperative prose in paragraphs, no headings, bullets for lists. Agent-facing, so no
conversational voice. Print it as one fenced block, commands and paths inline in backticks (never
the opening slash command), never a nested fence; then a `---` line before any note to the user;
every revision reprints the whole block.

## Check before printing

- Every path, id and command in the prompt exists or works — verified by a read-only lookup, not
  remembered.
- Every fact stated as settled was verified in this session or stated by the user; an inference
  is marked as one ("probably", "unverified") or cut.
- Nothing narrates this session (a ruled-out approach is not narration); for a checking job, nothing
  states this session's conclusion about the thing checked, nor a ruled-out approach.
- A session holding only this text can act without asking what was meant.

Done when all four hold.

## Boundaries

- The printed prompt is the product: write no file unless asked.
