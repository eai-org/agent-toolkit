---
name: review-ticket
description: Triage a ticket or ticket set before work starts: compare it against the codebase and save a review — verdict, feature walkthrough, and only the high-cost questions worth raising.
disable-model-invocation: true
license: MIT
metadata:
  author: Francesco Borzì
  version: "0.3"
---

# Review ticket

A pre-pickup triage glance: read a ticket — or a set of tickets forming one feature — usually
before anyone has started it, and decide whether it can be picked up or something must be
clarified first. The output briefs the developer on the feature and lists the questions worth
asking whoever owns the requirements.

## Input

- **Local ticket document(s)**: a single `.TICKET.md`, several, a ticket-set directory, or a
  `.TICKET.md` whose `## Ticket set` section lists siblings.
- **One or more ticket URLs or bare ids/keys**: delegate — even for a single one — to a subagent
  that invokes [fetch-ticket](../fetch-ticket/SKILL.md), so the tickets land on disk without the
  fetch bloating this session's context, then review the local files.

If the input is ambiguous or unrecognized, ask rather than guess.

**Set mode** applies to multiple tickets, a set directory, or a `.TICKET.md` listing a
`## Ticket set`. For a lone member file whose intended scope isn't obvious from the request, ask
whether to review the whole set or just that ticket.

## Read the materials

Read the input ticket file(s), **visually inspecting the downloaded images and design frames** —
they are part of the spec and often where the gaps hide.

**Widen only on demand.** When the input already tells the feature clearly — the journey, the
why, what each ticket delivers — review it as-is: reading beyond the input is never a required
step. Settle a specific doubt as cheaply as possible, and only to answer it:

- first, material already on disk: set siblings, a parent feature/epic, designs — a technical
  ticket's journey often lives in its parent or a sibling;
- remotely, only for what is still missing: a design inspected through its tool's MCP, a related
  ticket deep-dived from the ticket file's shallow related list (title, status, type), a missing
  parent fetched through the same fetch-ticket subagent (its family routing lands it flat in the
  set directory).

Unsure the extra context is worth it? Ask. Stop once the doubt is answered; never recurse the
related-ticket graph. Context never widens scope: the review covers only the input tickets, never
a parent's other children.

## Compare against the codebase

Weigh the ticket against the current code at adaptive depth: shallow by default, deeper only to
(a) ground the walkthrough in how the code behaves today and (b) settle whether a real blocker
exists. This is not an exhaustive both-sides verification: go as deep as a specific doubt demands,
no more.

## The question bar: both gates, or stay silent

A question reaches the output only when it clears **both**:

1. **Decision-expensive**: the answer blocks starting, or would be costly to reverse because it
   shapes the implementation (architecture, data model, approach). Cheap, easily-changed details
   (a color, a label, wording, spacing) are dropped even when unspecified.
2. **Not answerable from the materials**: if the ticket, the code, or the design settles it, settle
   it silently. Never ask what you can read.

**Zero questions is a clean, common result**: the ticket is ready to pick up. Never pad to look
thorough.

## Output

1. **Verdict line** first, so the answer lands at once, e.g.
   `2 questions to resolve before starting` or `Looks ready to pick up, no blockers.`
2. **Feature walkthrough**, in the voice of a senior dev briefing a colleague ("we need to
   implement X, Y and Z, and there are a couple of questions we might want to ask the PO first").
   A good structure could be layered, most important first, so the reader can stop at any depth:
   - **Nutshell** — the whole feature in 2–3 plain sentences.
   - **Flow-line** — the journey's shape in one line:
     `log in → client area (**klantportaal**) → submit request → status updates`.
   - **Journey** — one concrete user doing real actions: who they are, what they see and do, why
     the feature exists — never abstract capability-speak ("users are able to…"). Grounded in the
     real current behavior you saw in the code; where the contrast clarifies, a bold-led
     **Today** / **After** pair. Must fit one terminal screen (~25 lines).
   - **Ticket mapping** (set mode) — how each input ticket maps into the journey, one block per
     ticket, led by its linked ticket id and short title.

   Technical depth caps at "this screen calls endpoints X and Y to get its data": generally no
   need to go deep into architecture decisions. Single ticket: same layers, proportionally shorter.
3. **Questions**, when any cleared both gates: a numbered list, each item bracketed top and bottom
   by a ~40-char rule of `━` so the eye jumps between them. Each item carries the **question**
   (paste-ready, in a natural human voice, no AI tells, no dashes, citing the ambiguous part of the
   ticket or the relevant code to stay concrete) and a short **why-it-matters note to you** for
   deciding whether to forward it. When nothing cleared both gates, print only the verdict line.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 1 · <short label>

Question to ask, a sentence or two in a real person's voice.

Why it matters: the cost if we guess wrong.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The review is read by a human — raw in the terminal and later rendered as markdown, so format for
both: small blocks of a few sentences, each opened by a bold lead-in, blank lines between them,
~40-char `━` rules between major parts (nutshell + flow-line, journey, ticket mapping) — never
tables, nested lists, `#` headings, or a wall of text. In the saved file, embed the one or two
on-disk design frames that show the journey's main screens — a picture beats a paragraph.
User-facing texts in another language? Follow each mentioned page, area, or label with the name
the user sees, bold, in parentheses: "the client area (**klantportaal**)".

## Persist

Print the review and always save it too:

- **Set mode**: `<id>-<slug>.TICKET-REVIEW.md` in the set directory, named after the feature/set,
  so it sorts next to the `.TICKET.md` files.
- **Single ticket**: `<id>-<slug>.TICKET-REVIEW.md` next to its `.TICKET.md`.

The file must stand alone: carry relative links to each reviewed ticket file and to the parent
(its local file when on disk, else its tracker URL), so a later session finds everything from the
review file.

Close by pointing at `/verify-understanding <review-file>`; with no blockers, also
`/refine-ticket <ticket-file>` per ticket, in the set's suggested execution order.

## Boundaries

- **Read-only on tracker and code.** Never modify the tracker (comments, transitions, edits) or any
  source file. The only files written are fetch-ticket's outputs and the `.TICKET-REVIEW.md`.
- **Non-interactive on requirements.** The questions are the output: never grill the user to
  resolve them. Ask the user only operational things (an ambiguous input, a fetch that needs
  input, the set-scope call), never requirement decisions.
