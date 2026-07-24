# LANGUAGE-TEST — test-and-train harness for use-conversational-language

Adversarial loop measuring whether texts produced under
[use-conversational-language](../../skills/use-conversational-language/SKILL.md) pass as
human-written, and training the skill on what fails. Repo-internal: `test/` is never installed.

## Roles

- **Orchestrator** — the session running the test: runs iterations, triages verdicts, edits the
  skill, writes the run log. Never writes the test texts itself.
- **Generator** — one fresh subagent per iteration, clean-room: it receives the skill file and the
  scenario briefs, nothing else — no judge feedback, no mention of the experiment. A pass must be
  attributable to the skill text alone, not to lessons accumulated in a long-lived context.
  Generator prompt: "Read `skills/use-conversational-language/SKILL.md` and follow it. \<brief\>.
  Return only the text itself — no preamble, no explanation."
- **Judges** — per text, one blind headless call per panel model. Default panel, overridable per
  run: `claude-fable-5`, `claude-opus-4-8`, `claude-sonnet-5`. Each runs from a fresh temp dir
  with
  `--setting-sources ""` (verified: loads no user/project CLAUDE.md, no memory):

  ```sh
  cd "$(mktemp -d)" && claude -p --model <model-id> --setting-sources "" "<judge prompt>"
  ```

  Judge prompt (fixed; `{context}` from the scenario, `{text}` the generated text):

  ```
  Guess whether this text has been written by a human or is AI generated.
  First line of your reply: exactly HUMAN or AI. Then briefly explain why.
  Judge from the text alone.

  Context: {context}

  Input text:

  {text}
  ```

  On a malformed verdict (first line not HUMAN/AI), rerun that judge call once.

## Procedure

A run takes a list of scenario ids (one, several — default: all). Per run, max 3 iterations:

1. Spawn a clean-room generator for the selected briefs; collect one text per scenario.
2. Judge each text with the panel. A scenario passes iff every judge says HUMAN; the run
   passes iff every selected scenario passes. Pass → write the run log, report, stop.
3. On failure, triage every tell the judges cite, across all failed scenarios:
   - Tell already banned by a skill rule → generation slip; regenerate, no edit. But the same rule
     slipping repeatedly (this run or in earlier run logs) means its wording fails to steer —
     rewording it for enforceability (cf. the dash rule's built-in re-read check) is a real edit.
   - Tell no rule covers → skill gap; candidate edit.
4. Apply at most one edit per iteration: the candidate with the strongest support across judges
   and scenarios. Route it through `/self-improve` (which routes SKILL.md writes through
   compact-skill-creator). **Auto-apply exception**: for these runs the skill owner pre-authorizes
   applying without per-edit approval — self-improve's confirm-first rule is waived here, and only
   here. Never commit; the owner reviews the accumulated diff. On a run's first edit, bump the
   skill's version once.
5. Next iteration: regenerate every selected scenario with the updated skill (an edit for one
   genre can regress another), fresh generator, fresh judges.

After 3 iterations without a full pass: stop and report what still fails and why.

## Run log

Write `runs/<YYYY-MM-DD-HHmm>.md` (gitignored): skill version under test, panel, selected ids,
then per
iteration and scenario the generated text, the three verdicts with tells cited, the triage
decision, and any applied edit (old → new). End with the outcome.

## Scenarios

Each entry: id, the judge-prompt `{context}`, and the generator brief. Briefs are fictional but
concrete so the generator never has to invent the substance.

- **`reviewer-comment`** — "a review comment on a colleague's pull request"
  Reviewing a teammate's PR: a new `formatDate` helper in `utils/date.ts` duplicates the existing
  `DateFormatter` in `shared/format.ts`. Ask to reuse the existing one.
- **`author-reply-accept`** — "an author's reply to a review comment on their own pull request"
  A reviewer flagged that your new orders query scans without an index and suggested one on
  `(tenant_id, created_at)`. They're right and you've added it. Reply.
- **`author-reply-pushback`** — "an author's reply to a review comment on their own pull request"
  A reviewer asks you to split a 40-line data migration into three scripts per the style guide.
  You'd keep one file: the steps must run in a single transaction. Reply.
- **`chat-explanation`** — "a chat message to a teammate"
  A teammate asks why deploys are blue-green yet DB migrations run before the switch. Explain:
  expand-contract — during cutover both app versions run against the same schema, so migrations
  must stay backward-compatible and land first.
- **`short-answer`** — "a chat message to a teammate"
  A teammate asks how retry backoff works in the queue consumer: exponential from 1s, capped at
  5 min, with jitter, dead-letter queue after 8 attempts. They asked how it works, nothing more.
- **`code-comment`** — "a comment in application source code"
  The `ready` handler is registered before `init()` because the library fires `ready`
  synchronously during init, so a later registration misses it. Write the comment above the
  registration.
- **`commit-message`** — "a git commit message"
  The commit fixes duplicate invoices created when two webhook deliveries for the same event
  race; the fix checks an idempotency key inside the transaction. Write the message.
- **`pr-description`** — "a pull request description"
  The PR adds per-API-key rate limiting to the public API: token bucket, limits configurable per
  plan, 429 with Retry-After, a metric for rejected calls. Write the description.
- **`slack-ask`** — "a message in a team chat channel"
  You need a review on PR #482 today — it must make the release cut and touches the billing
  module Marta knows best, but she may be off. Ask the channel.
- **`issue-comment`** — "a comment on a bug-tracker issue"
  On "CSV export intermittently empty": you reproduced it with exports over 10k rows — the worker
  hits its 30s timeout and the partial S3 multipart upload is aborted, leaving an empty file.
  Smaller exports are fine. Report the findings; there's no fix yet.
- **`standup`** — "a written standup update in team chat"
  Yesterday: finished the pagination fix, reviewed two PRs. Today: the CSV export bug. Blocked:
  waiting on staging access from IT.
- **`maintainer-reply`** — "an open-source maintainer's reply to a bug report from an unknown
  user"
  A user reports your CLI tool crashes on startup on Node 18, stack trace pointing at config
  parsing. To go further you need their config file (secrets redacted) and OS. Reply.
- **`approval-summary`** — "an approving review summary on a colleague's pull request"
  Approving a teammate's PR with two non-blocking nits: `tmpList` deserves a clearer name, and
  the empty-input case has no test. Write the closing comment.
