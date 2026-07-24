# LANGUAGE-TEST — test-and-train harness for use-conversational-language

Adversarial loop measuring whether texts produced under
[use-conversational-language](../../skills/use-conversational-language/SKILL.md) pass as
human-written, and training the skill on what fails. Repo-internal: `test/` is never installed.

## Roles

- **Orchestrator** — the session running the test: runs iterations, triages verdicts, edits the
  skill, writes the run log. Never writes the test texts itself.
- **Scenario writer** — one fresh subagent per run: writes the scenario set from the genre
  palette (see Scenarios), clean-room — no skill text, no judge feedback, no earlier runs — so
  briefs can't be tailored to what the skill already handles.
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

  [judge.sh](judge.sh) runs the whole panel over an iteration this way — parallel calls, the
  malformed-verdict rerun included — writing `iter<N>/verdicts/<id>.<model>.txt`; override the
  panel with `PANEL="…"`.

## Procedure

A run takes a list of genre ids (one, several — default: all) and a working dir in the
session's scratch space. Per run, max 3 iterations:

1. Spawn the scenario writer; save the set to `<run-dir>/scenarios.tsv` (id, judge context,
   brief — tab-separated).
2. Spawn a clean-room generator for the run's briefs; one text per scenario, to
   `<run-dir>/iter<N>/texts/<id>.txt`.
3. Judge each text with the panel: `./judge.sh <run-dir> <N>`. A scenario passes iff every judge
   says HUMAN; the run passes iff every selected scenario passes. Pass → write the run log,
   report, stop.
4. On failure, triage every tell the judges cite, across all failed scenarios:
   - Tell already banned by a skill rule → generation slip; regenerate, no edit. But the same rule
     slipping repeatedly (this run or in earlier run logs) means its wording fails to steer —
     rewording it for enforceability (cf. the dash rule's built-in re-read check) is a real edit.
   - Tell no rule covers → skill gap; candidate edit.
5. Apply at most one edit per iteration: the candidate with the strongest support across judges
   and scenarios. Route it through `/self-improve` (which routes SKILL.md writes through
   compact-skill-creator). **Auto-apply exception**: for these runs the skill owner pre-authorizes
   applying without per-edit approval — self-improve's confirm-first rule is waived here, and only
   here. Never commit; the owner reviews the accumulated diff. On a run's first edit, bump the
   skill's version once.
6. Next iteration: regenerate every selected scenario with the updated skill (an edit for one
   genre can regress another), fresh generator, fresh judges.

After 3 iterations without a full pass: stop and report what still fails and why.

## Run log

Write `runs/<YYYY-MM-DD-HHmm>.md` (gitignored) via `./assemble-log.sh <run-dir> <log>`. It
stitches, in order: `header.md` (skill version under test, panel, selected genres, per-iteration
pass counts), the scenario set, per iteration and scenario the generated text and the verdicts
with tells cited, `triage-iter<N>.md` (triage decision, any applied edit old → new), and
`outcome.md` — all written by the orchestrator into the run dir.

## Scenarios

Never reuse scenarios: each run gets a fresh set, so the skill trains on voice, not on a
memorized benchmark. The scenario writer produces one scenario per selected genre: the genre's
id and judge context verbatim, plus a new brief. Briefs are fictional but concrete so the
generator never has to invent the substance — name the exact symbols, values, and people (e.g.
"a new `formatDate` helper in `utils/date.ts` duplicates the existing `DateFormatter` in
`shared/format.ts`; ask to reuse the existing one").

Genre palette — id, judge-prompt `{context}`:

- `reviewer-comment` — "a review comment on a colleague's pull request"
- `author-reply-accept` — "an author's reply to a review comment on their own pull request";
  the brief makes the reviewer right and the fix already done
- `author-reply-pushback` — "an author's reply to a review comment on their own pull request";
  the brief gives a solid reason to keep the code as is
- `chat-explanation` — "a chat message to a teammate"; the brief is a why/how question deserving
  a short walkthrough
- `short-answer` — "a chat message to a teammate"; the brief wants just the facts
- `code-comment` — "a comment in application source code"
- `commit-message` — "a git commit message"
- `pr-description` — "a pull request description"
- `slack-ask` — "a message in a team chat channel"
- `issue-comment` — "a comment on a bug-tracker issue"
- `standup` — "a written standup update in team chat"
- `maintainer-reply` — "an open-source maintainer's reply to a bug report from an unknown user"
- `approval-summary` — "an approving review summary on a colleague's pull request"
