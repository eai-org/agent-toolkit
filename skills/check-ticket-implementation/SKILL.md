---
name: check-ticket-implementation
description: Check how much of a ticket is already implemented — split it into requirement blocks, judge each against the code, and save a human-readable TICKET-STATUS report in the planning dir.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  author: Francesco Borzì
  version: "0.3"
---

# Check ticket implementation

Judge how much of a ticket is already implemented and report it so the user sees at a glance what
is done, what isn't, and what still needs attention.

## Gather

Input is a ticket URL / bare id — run [fetch-ticket](../fetch-ticket/SKILL.md) on it (it resolves
the tracker and planning dir and persists the `.TICKET.md`) — or a path to an already-fetched
ticket file or its task dir. Ambiguous input: ask, don't guess.

Run the fetch in a **subagent** when the runtime supports one, so its tool traffic stays out of
this session's context: it returns the ticket-file path plus any blocker it hit (ambiguous
tracker, auth, no planning-dir convention) for you to settle with the user — it never guesses.
Without subagent support, invoke fetch-ticket inline.

The **ticket text is what gets annotated** — its `.REQUIREMENTS.md` (same dir and `<id>-<slug>`
base — a shared dir may hold siblings') may be read as context for intent, never annotated in its
place. Inspect downloaded attachments and design frames when they bear on a requirement being
judged.

**Evidence base**: the current working tree, uncommitted changes included — unless the invocation
names something else (a branch, PR, commit range); then judge against that.

## Blocks

Turn every requirement-bearing statement into a block: description, acceptance criteria, and
comment statements that add or change requirements (attribute those, e.g. "from comment by X").
Drop metadata, related-ticket lists, and chatty comments — the full text stays in the `.TICKET.md`.

- One block = one independently verifiable requirement, quoted **verbatim** under a short generated
  title, preserving ticket order.
- **Split on mixed verdict**: if two halves of a candidate block could end with different statuses,
  they are two blocks. PARTIAL always means one requirement itself half-built, never a bundle of a
  done and a not-done thing.

## Judge

Statuses: ✅ DONE · 🟡 PARTIAL · 🟥 NOT DONE · ⚪ NOT VERIFIABLE (can't be judged from the code —
say why, e.g. a manual deploy step).

- **The ticket text is the contract.** Tests, i18n, docs, and other project conventions affect the
  verdict only when the ticket demands them; a gap there is at most a remark in the note, never a
  downgrade.
- Verify by **reading**: search and read the code paths relevant to each block. When reading alone
  can't settle a verdict, say so in the note instead of guessing. Anything beyond reading —
  executing code, driving the app or a browser — only with the user's ok.
- Every block gets a 1–2 sentence note and 1–3 `file:line` evidence refs showing where it was
  checked; for 🟡/🟥 the note must state what's missing or remaining.

## Report

Write `<task-dir>/<id>-<slug>.TICKET-STATUS.md`, overwriting any previous run — it is a snapshot of
now, and the header says when and against what. (No task dir and nothing to fetch? Follow the
project's/user's planning-dir convention, defaulting to `.agents/plans/`; ask only if genuinely
ambiguous.)

Format for human eyes — verdicts up front, blocks fenced by `━` rules:

```markdown
# <ticket title> — implementation status

> **Ticket** [<id>](<url>) · **Checked** <YYYY-MM-DD> · **Against** <branch>@<short-sha> (+ uncommitted)

**4 ✅ · 2 🟡 · 1 🟥 · 1 ⚪**

Needs attention: <titles of the 🟡/🟥 blocks>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### ✅ DONE — <block title>

> <verbatim ticket text>

<note> — `path/to/file.ts:42`

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Wrap up

Print the tally line, the needs-attention titles, and the project-relative path of the report.
Nothing more — what to do about the gaps is the user's call.

## Boundaries

- **Read-only** on tracker and code: never comment on or transition the ticket, never modify
  source. The only file written is the `.TICKET-STATUS.md` (plus whatever fetch-ticket persists
  when delegated).
- Never grill the user on requirement questions; uncertainty lands in the notes.
