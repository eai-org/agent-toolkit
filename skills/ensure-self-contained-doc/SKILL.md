---
name: ensure-self-contained-doc
description: Ensure a document written in this session is self-contained for the fresh session that will pick it up, by filling in what a fresh reader finds missing.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "0.1"
---

# Ensure self-contained doc

A fresh **reader** plans the next session's work and reports where it had to ask or guess; this
session fills in, from what it knows, only what the next session needs.

Never check whether the document's claims are true (against the code, a ticket): that takes a
session that did not write it.

## Input

- **Document** — one file a fresh session will act on, of any type or name (a brief,
  requirements, a plan, a prompt saved to a file): from the invocation; else the one this session
  wrote when that is clear, stated in one line before the reader starts; else asked once.
  Chat-only text is out of scope: say so and stop.
- **Starting instruction** — what the next session will be told to do with the document: from the
  invocation; else from this session when clear there (a launch command a writing skill printed,
  what the user said the document is for), stated in one line before the reader starts; else
  asked once.
- **Excluded paths** — the files the document was written from and must stand without: its
  ticket, earlier-phase documents (a plan's requirements), this session's notes and scratch
  files. They typically sit beside it in the planning directory, but only a source is excluded,
  never a file the document itself sends the next session to. Worked out by this session and
  stated before the reader starts, in one line with the starting instruction, also when there are
  none (a prompt written from the conversation, a document that points to all its sources).

A session that neither wrote the document nor discussed its decisions (a fresh one run on an
older document) can answer little: say so, and that every question that matters will go to the
user; continue only on the user's yes. Editing an existing document after discussing it counts as
writing it.

Done when document, starting instruction and excluded paths are settled and a non-author session
has that yes.

## Reader

One fresh-context subagent acts as the next session, on the model the invocation names, else the
harness default. Its brief is the text below and nothing more — nothing this session decided or
thinks of the document — and needs no user approval:

```
You are a fresh session, just told:

<starting instruction>

The document is <path>. Plan that work step by step, as if about to do it, thinking each step
through far enough to know what it needs from the document. Read whatever you need in the
project. Never read <excluded paths>: the document must stand without them. Write nothing, run
nothing, delegate nothing.

Before reporting a question, try to answer it from the document and the project (its docs, its
code, the skill the task uses). Report three lists, "none" for an empty one:

1. Questions you could not answer: each with the step it blocks, where in the document you looked
   for the answer, and what you would do if nobody answered.
2. Contradictions in the document: both places quoted.
3. Assumptions: each point the document was silent on and you settled yourself, with where in it
   you looked and the choice you made.
```

Nothing excluded → the brief drops its "Never read" sentence.

A subagent cannot run a slash command: when the starting instruction is one, the brief adds,
right after it, to read that skill's file (by path, when this session can resolve it) and plan
the work as it describes.

No subagents in the harness → print the brief as a prompt the user runs in a clean session, and
continue at Sort from the reply they paste back. Never a pass by this session in the reader's
place: the session that knows the answers cannot see which are missing.

Done when the reader's three lists are back, possibly all empty.

## Sort

A report that a claim of the document is false (a function it names does not exist, it disagrees
with the code or another source), in whichever list, is a **claim to check**: never sorted or
verified, and the document does not change for it.

Every other reported item gets exactly one outcome:

- **Added** — the user stated the answer, this session verified it (other than by reading the
  project: that is Already findable) or, for a part of the document this session wrote or
  decided, only an excluded path holds it, and without it the next session would be blocked or
  could do the wrong thing.
- **Yours** — needed, but this session does not know the answer or would have to infer it. An
  inferred answer is never written as decided. An answer only an excluded path holds, for a part
  this session neither wrote nor decided, is sorted here, recommending what that file says: the
  document may depart from it there on purpose.
- **Not needed** — the next session can decide it: any reasonable choice works, or deciding it is
  that session's own task, alone or with the user as its instruction or skill says (a design fork
  a planning skill puts to the user). Nothing added.
- **Already findable** — the answer is in the document or the project, excluded paths aside, and
  the reader missed it. Nothing added, except a one-line pointer (the answer and where it lives,
  never an excluded path) when finding it takes a search: it is in neither the document, a file
  the document points to, nor the docs every session loads.

Nothing is added only because the reader asked.

Check each assumption against what was decided: a wrong one is a gap like an unanswered question,
and the kind that matters most, since a real next session would not stop to ask. A right one is a
gap too when another reasonable choice would have been wrong, as the next session may make that
one; otherwise it is Not needed. A contradiction is settled only from what this session decided,
never by checking the code.

Done when every item of the three lists has one outcome or is a claim to check.

## Write

Every text written (an Added item, a Yours answer, a pointer) goes in once, where the reader
looked for it: of several places, or none named, the one a statement of its kind belongs in. A
contradiction's replaces the wrong text. Never an appended clarifications section. It reads as
the author's own text, with no trace of the check.

Added items and pointers go straight in, with no approval per item. Yours items are asked one at
a time, each with a recommended answer, worded via `explain-in-simple-language` when available,
and the user's answer is written. One the user cannot or will not answer now is written as an
open question, with the tentative answer when there is one.

Done when the document holds every Added and Yours item and each pointer, and no other change.

## Rounds

A round that changed the document earns one more, its new reader given the same brief and told
nothing of the earlier round. Rounds stop when one changes nothing, or after 2; the user may stop
earlier or ask for more.

A later reader reporting an item this check wrote a text for (an Added answer, a Yours answer the
user gave, a pointer), as a question again or as a point it settled itself, shows the text did
not work: the item keeps its outcome, is not sorted again, and the text is repaired in place, by
rewording or moving it, never by adding a second copy. The repair counts as a change to the
document, for the rounds and the summary.

Any other item a later reader reports again:

- Not needed, Already findable with nothing written, or a Yours written as an open question → it
  keeps that outcome, is not sorted or asked again and appears once in the summary;
- the report shows something the earlier one did not (a wrong assumption where there was only a
  question) → sorted again, whatever its earlier outcome.

Done when a stop condition has ended the rounds.

## Summary

Print how many rounds ran, then every item under its outcome or as a claim to check:

- **Added** and **Yours** — per item, the reader's question, contradiction or assumption, then
  the exact text written and its section, plus the text it replaced for a contradiction: planning
  files are often untracked, so no diff would show it.
- **Not needed** and **Already findable** — per item, a one-line reason, so the user can overrule
  it; a pointer written is shown like an Added text.
- **Claims to check** — each once, as reported, to check in a session that did not write the
  document.

When the last round changed the document, name its edits as read by no reader, so the user knows
another round can be asked for. Then name as possibly stale each document derived from the edited
one (a plan written from the edited requirements) that this session knows of or finds beside it.
No next-phase command.

Done when all are printed.

## Boundaries

- Files written: the document only.
