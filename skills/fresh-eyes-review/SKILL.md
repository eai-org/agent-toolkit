---
name: fresh-eyes-review
description: Fresh-eyes review of a changeset by a fresh-context agent — catches what the authoring context reads past.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "1.5"
---

# Fresh-eyes review

A context that produced a change reads its intent, not its text, so same-context review misses what
a fresh reader would catch. The fix is procedural: a reviewer whose context holds only the
artifacts.

## Workflow

1. **Resolve the inputs.** The changeset: whatever the invocation names — a branch, a commit, a
   diff range, a draft vs its original. Given none, infer it from the session — usually the work
   just finished, committed or not; no VCS required. With no session context to draw on, fall back
   to git: the working tree against HEAD (`git diff HEAD` plus untracked files) and the branch
   against its merge base with the fetched default branch of its tracking remote (`git ls-remote
   --symref <remote> HEAD`). One non-empty → take it; both → offer both in step 2's proposal;
   neither, or no target found → ask what to review.
   Pin the changeset as concretely as the environment allows — a diff or commit range where one
   exists, otherwise the touched files, with their prior state when reconstructable. Alongside it,
   a short statement of what the change is supposed to achieve, when one exists (the task as
   stated, a PR or ticket description); when this session authored the change, never include the
   session's own reasoning, plan, or messages — leaked rationale recreates the blindness the fresh
   context exists to remove. Strip what the change deliberately leaves for later, whatever its
   source: naming it walls off the omissions lens below. Done when changeset and intent are pinned
   down and free of authoring context.
2. **Confirm the prompt.** Assemble the reviewer prompt — changeset, intent, the mandate and
   exclusions below, and any further reviewer instructions the invocation supplies (e.g. what to
   report back). When the invocation supplied changeset, intent, and mandate explicitly (e.g. a
   driving skill), nothing was inferred, so skip the confirmation and proceed. Otherwise show
   the prompt to the user verbatim and wait for approval; fold any doubt about an inferred
   changeset into the proposal rather than asking separately. Text emitted before a tool call may
   not be displayed, so never show the prompt and then ask via a question tool in the same turn —
   end the turn with the prompt and a plain-text ask, or embed the prompt in the question tool.
   Done when the user has approved the prompt, as shown or amended — or the explicit-inputs skip
   applied.
3. **Spawn one fresh-context reviewer** (a subagent or equivalent isolated session, e.g. a
   non-interactive run of the agent's own CLI with the prompt) with the prompt, free to read any
   surrounding project material — except the paths the prompt lists as excluded: any exclusions
   the invocation supplies, plus, when this session authored the change, session-authored files
   that are not part of it (plans, notes, scratch), since a fresh context cannot tell them apart.
   The prompt names the changeset by reference (range, SHAs, paths), never pasting diff or file
   bodies. The reviewer reads sparingly, since every step re-sends all it has read: `--stat`
   first, each changed file's diff once, the code around a hunk by line range (a whole file only
   when short), code outside the diff by targeted search, each governing doc once and only those
   governing the files in scope; generated or vendored files never line by line but against their
   source, regenerated into scratch and diffed when the generator is at hand; an output the
   harness truncated or saved to a file is searched or read by range, never whole again. It spawns
   no agents of its own.
   It writes nothing into the project: every run it makes (tests, probes) disables or redirects to
   scratch space its side outputs (coverage, reports, snapshots), which tooling writes in-tree by
   default. Before spawning, create a marker file in scratch space and save there the file list
   (`find <dir> -type f -not -path '*/.git/*'`) of each repo or directory the reviewer may run in;
   afterwards, a listed file now gone was deleted, an unlisted one created, and a listed one newer
   than the marker (`-newer <marker>`) modified. Its mandate, unless the invocation redirects it
   (e.g. security only): regressions and correctness, including contradictions with surrounding
   code, rules, or docs — though matching surrounding code is not correctness: verify any pattern
   the change extends or mirrors is itself sound, since completing a broken rollout inherits its
   breakage; ambiguities a reader without context would trip on; when an intent statement was
   given, whether the change does what it says; and omissions — what the change should have touched
   and didn't: an altered contract (file format, payload, schema, config or CLI surface) has
   counterparts that must move with it — templates, samples, fixtures, seed data, docs. Find those
   by content, not location: they often sit outside the changed tree and its stack, and a literal a
   changed file copies from a shipped artifact (a header row, a sample payload) names one. A
   deferral the submission itself states — a PR description or commit subject carried verbatim — is
   a claim to test, not scope conceded. Tough but grounded, aimed at mistakes that matter: every
   finding names its location and a concrete failure scenario; style nits, speculation, and padding
   are out of scope, and zero findings is a valid outcome. Besides what the invocation asks, it
   returns its findings numbered — one mistake repeated at several sites is one finding listing
   them all (several behaviours left untested are one); distinct mistakes never share one, not
   even a bug and the test that misses it, nor two kinds grouped by theme (a missing test and a
   convention breach in one spec) — each citing the lines it read as evidence
   (`path:lines`) and re-checked against them before returning, dropped when they disprove it;
   and what in scope it did not read, by name (or that it read everything).
   Out of scope bounds what is reported, never what is investigated: a pre-existing anomaly in
   the mechanism the change touches is a reason to audit it. If the harness cannot
   isolate a context, fall back to an adversarial pass over the same inputs in the main session.
   Done when an isolated reviewer has returned its findings, or the fallback pass ran and its result
   is flagged as same-context (weaker) — and each repo or directory the reviewer may run in,
   compared against that baseline, holds nothing the review wrote: created files removed, or
   reported when something else may have written them (another session, a watcher); modified and
   deleted ones reported.
4. **Report back.** Relay every finding intact — location and failure scenario included — plus
   whatever else the reviewer was instructed to return; add the session's own assessment when
   useful, but never silently drop or soften a finding. What to do with the findings is the
   caller's decision, not this skill's. Done when every reviewer finding appears in the report.
