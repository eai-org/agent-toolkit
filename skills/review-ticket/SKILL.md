---
name: review-ticket
description: Triage a ticket or ticket set before work starts — compare it against the codebase and save a review covering verdict, feature walkthrough, and only the high-cost questions worth raising.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "1.2"
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
related-ticket graph — except to kill a candidate question (see the question bar). Context never
widens scope: the review covers only the input tickets, never a parent's other children.

## Compare against the codebase

Weigh the ticket against the current code at adaptive depth: shallow by default, deeper only to
(a) ground the walkthrough in how the code behaves today and (b) settle whether a real blocker
exists. This is not an exhaustive both-sides verification: go as deep as a specific doubt demands,
no more.

## The question bar: both gates, or stay silent

A question reaches the output only when it clears **both**:

1. **Decision-expensive**: the answer changes what this developer builds — it blocks starting,
   or would be costly to reverse because it shapes the implementation (architecture, data model,
   approach). Cheap, easily-changed details (a color, a label, wording, spacing) are dropped even
   when unspecified. A real gap whose fix lies wholly outside the input tickets' scope (another
   repo, another team) is a **handoff**, not a question: it ships as an action item with a
   paste-ready message to its owner, and starting never waits on it.
2. **Survives the challenge**: a challenger (next section) hunted for the answer across every
   checkable source and came back empty-handed, with a complete evidence trail.

**Cheap-settle first.** Before challenging, settle each candidate as far as material already read
or trivially reachable allows — set siblings on disk, code already open, an obvious lead (a
telling title in an already-fetched relative's related list, a parent's other children included, a
code path an earlier check surfaced). What a check settles, settle silently: never ask what you
can read. The exhaustive hunts — whole-repo sweeps, tracker keyword search, design-tool
exploration — are the challenger's job alone: never duplicate them here, and pass any lead you
didn't follow into the challenger prompt.

**Zero questions is a clean, common result**: the ticket is ready to pick up. Never pad to look
thorough. Zero candidates → zero challengers.

## The challenge

Each surviving candidate gets one challenger — a subagent or equivalent isolated context, fresh
per question, spawned in parallel, strictly read-only — prompted from the template in
[challenger-prompt.md](challenger-prompt.md). When the harness cannot isolate a context, run the
same template procedure inline over the same sources and flag each surviving question's why-note
"challenged same-context (weaker)".

Judge the verdicts asymmetrically, in both directions:

- **KILLED / RESHAPED — verify before accepting.** Accept only on a verifiable citation (file
  path + lines + verbatim quote, ticket id + quoted text, design frame id): open the load-bearing
  citation yourself and confirm it exists as quoted **and answers the question as asked** —
  related evidence is not an answer. Either check fails → reject the verdict, the question stays.
  A derivation kill rests on multiple quotes composing an inference: verify each quote and that
  the conclusion follows.
  RESHAPED is a partial kill: same citation bar for the answered part, and the trail must
  explicitly cover the remainder; the narrowed question is not re-challenged.
- **OPEN — accept only with a complete trail**: every source class probed, with what it said. On
  an incomplete trail (a dead or errored challenger counts as one): unless the invocation preset
  a re-challenge budget, ask the user — one batched ask covering all weak trails — whether to
  spend a re-challenge aimed only at the unchecked sources. Still incomplete after that → keep
  the question, naming the unchecked sources in its why-note; an unavailable source (rate-limited
  tool, missing repo) is recorded as unchecked, never exhausted. A question is dropped only by a
  verified kill, never by challenger failure.

Fold the verdicts in: KILLED → settled silently, the answer surfacing as a walkthrough fact when
it changes what the developer must know; RESHAPED → the question narrows; OPEN → the question
ships, its trail feeding the why-note (exhausted and unchecked sources). No OPEN or narrowed
question ships before the session has rerun the Derive moves (challenger prompt, step 6) itself
over the returned trail — a challenger can return every fact yet miss the inference. A derived
answer is a kill, held to the same citation bar; when enacting it lies outside the input tickets'
scope, the question converts to a handoff.

## Output

1. **Verdict line** first, so the answer lands at once, e.g.
   `2 questions to resolve before starting` or `Looks ready to pick up, no blockers.`
   Handoffs never count as blockers here.
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

   Introduce each core domain term in plain, memorable words at first use — a contrast or
   direction hook beats a bare definition.

   Technical depth caps at "this screen calls endpoints X and Y to get its data": generally no
   need to go deep into architecture decisions. Single ticket: same layers, proportionally shorter.
3. **Questions**, when any survived the question bar: a numbered list, each item bracketed top
   and bottom by a ~40-char rule of `━` so the eye jumps between them. Each item carries the
   **question** (paste-ready, citing the ambiguous part of the ticket or the relevant code to
   stay concrete) and a short **why-it-matters note to you** for deciding whether to forward it.
   A handoff uses the same block format, `### Handoff · <short label>` in place of the number.
   Actually invoke [use-conversational-language](../use-conversational-language/SKILL.md) and
   follow it before writing the questions or handoff messages — reciting its rules from memory
   does not count; runs with neither skip it. Not installed: write plain prose instead, no dashes and no AI tells. When nothing survived, print only the verdict line
   plus any handoffs.

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
tables, nested lists, or a wall of text; no `#` headings apart from the `### <n> · <label>` line
opening each question item. In the saved file, embed the one or two on-disk design frames that
show the journey's main screens — a picture beats a paragraph.
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

End the saved file — never the printed review — with a `## Challenge log` appendix, opened by a
one-liner saying it's tracing only and safe to ignore: each killed question (a reshape's answered
part included) with the answer that settled it and its citation, and each cheap detail the
question bar dropped, with the default assumed.

Close by pointing at `/verify-understanding <review-file>`; with no blockers, also
`/refine-ticket <ticket-file>` per ticket, in the set's suggested execution order.

## Boundaries

- **Read-only on tracker and code.** Never modify the tracker (comments, transitions, edits) or any
  source file. The only files written are fetch-ticket's outputs and the `.TICKET-REVIEW.md`.
- **Non-interactive on requirements.** The questions are the output: never grill the user to
  resolve them. Ask the user only operational things (an ambiguous input, a fetch that needs
  input, the set-scope call), never requirement decisions.
