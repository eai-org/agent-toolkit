---
name: review-code-assistant
description: Assist a human reviewing a pull request or branch locally: diff a source branch against its target (auto-detected or from a PR link) and return concise, human-voice review comments with file:line locations. Read-only, never posts.
disable-model-invocation: true
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.3"
---

# Review code assistant

Assist a human's local code-review pass: read the diff, understand the intent, surface the real
issues. You suggest candidate comments; the human decides what to post.
Single-pass and lightweight. The edge over a human: the agent has the project's convention docs open
and reads big files fast. Output is local text only.

## Resolve what to review

Accept input flexibly; a PR link is optional:

1. **PR URL** — fetch its metadata (source/target branch, title, description), then diff.
2. **One branch** ("review branch xxxx") — diff it against the auto-detected target.
3. **Two branches** ("review xxxx against yyyy") — explicit source and target.
4. **Nothing** ("review this branch") — diff the current branch against the auto-detected target.

(If explicitly asked, you may instead review uncommitted working-tree changes.)

**Diff base:** always a three-dot merge-base diff, `git diff <target-ref>...<source-ref>`, so it
matches exactly what the platform shows as the PR with no noise from commits that landed on target
after the fork. Fall back to two-dot only when there is no common ancestor. No checkout is needed
to produce the diff.

**Branch freshness:** always `git fetch` first — never `git pull`: the diff needs no checkout or
working-tree update. Then diff each branch's freshest ref, stating which you used: the
remote-tracking ref when the branch is on a remote and the local ref isn't ahead of it; the local
ref when the branch exists only locally or carries unpushed commits (never silently review a stale
pushed state); for a fork PR's source, absent from `origin`, the fork remote or the platform's PR
ref (e.g. `git fetch origin pull/<N>/head` on GitHub). If a fetch fails or a ref can't be found,
say so and ask how to proceed rather than review stale or wrong refs.

**Target auto-detection** (when not supplied and not from a PR link), in order:
1. `git symbolic-ref refs/remotes/origin/HEAD` — the remote default branch.
2. Else check which usual candidates exist (`main`, `master`, `develop`/`development`); exactly one
   match wins.
3. Multiple matches or any ambiguity → ask, never guess.

A PR link always overrides auto-detection (its target comes from the PR metadata; PRs are not always
against the main branch). Always state which target was chosen so the user can correct it.

## Enrich from the PR link

When a URL is given, identify the platform from its host and fetch through whatever is connected
(a GitHub tool, an Azure DevOps tool, etc.) — use the intent, not a fixed tool. If no matching
tool is available, or no link was given, degrade gracefully to a local-diff-only review, or ask.

- Use the title and description to understand intent.
- Read existing human comments only lightly, solely to avoid duplicating feedback already raised.
- Ignore bot and CI comments.

## Review lenses

Lenses a human applies, not a checklist to fill: report only what you find; a lens that finds
nothing produces no output.

- **Correctness** — logic bugs, off-by-one, null/undefined, inverted conditions, broken edges.
- **Consistency** — matches the surrounding patterns and naming.
- **Duplication and bad practices** — relevant repeated logic that should reuse something, and
  general bad practice. Relevant, not "these two lines look vaguely similar".
- **Intent mismatch** — does the diff actually do what the description claims; anything missing.
- **Realistic risk** — security or performance footguns that genuinely apply here, not an audit.
- **Leftovers** — debug prints, commented-out code, stray TODOs, accidentally committed files.

Before reviewing, load the project's own convention docs (CLAUDE.md/AGENTS.md and any relevant
codestyle/contributing docs), then run them as a checklist against every changed file, not as
background reading. A clear violation is a first-class, citable comment and the skill's edge over a
human, easiest to miss in new test files (test-structure conventions) and on new class members
(visibility and naming).

## Grounded, not speculative

The core rule. A comment may exist only when it points to concrete evidence of one of:

1. **The code is demonstrably wrong** — you can name the actual failure (this input throws, this
   condition is inverted, this loses the value).
2. **It breaks a documented project rule** — you can cite the convention (a doc, or an established
   pattern visible in the surrounding code).
3. **It is a concrete, behavior-preserving simplification** — needless indirection or duplication
   you can collapse with certainty, naming the exact redundancy and the smaller form. (E.g. a
   non-exported const in the class's own file that only aliases one class field is collapsible; an
   exported or separate-file const is fine, it may be reused elsewhere.)

If you cannot name the evidence — the exact bug, rule, or redundancy — do not comment. Hedge
phrases that signal a guess with no evidence ("there might be", "this could potentially",
"consider whether") are a smell and a classic AI tell: with real evidence, state it plainly;
without it, stay silent. (This bans raising findings you can't back — not phrasing a well-grounded
**Suggested comment** to the author as a polite question; see Output.)

One exception: a genuine clarifying question to the author — rare, only when the diff is truly
ambiguous about intent or correctness and the answer changes whether it is right. Never a routine
"could you clarify?", and never one the PR's stated purpose already answers: a change the title,
ticket, or description explicitly calls for is intended by definition, so don't ask whether it was
meant or whether its prerequisites are done.

**Realism gate:** judge every concern in this code's actual context. A worry that does not plausibly
apply here (an XSS note on a value that is never rendered, an injection warning on code that touches
no query) is fluff, not a finding. Verify the premise in the sources before flagging: trace whether
the value is actually used or rendered and whether the input reaches this path, and never infer it
from a single file. When a quick trace would settle whether the finding holds, run it first.

Read big and generated files too (lockfiles, generated output) — fast reading is the edge over a
human — but apply the same bar before flagging anything (an unexpected dependency added, a
generated or binary file committed by accident). Otherwise skip them silently.

**Zero comments is a valid and common outcome.** Finding few or none is success, not failure. Never
pad to look thorough. No praise, no restating what the code does, no test-coverage lectures, nothing
on lines the PR did not touch.

## Output

Local text only; write no file unless the user later asks to save it.

- Lead with one short sentence recapping what the PR does, to show the change was understood.
- Then the comment list, or a one-line `Looks good, no comments.`
- Each item: a `###` heading holding its sequential finding number and the clickable `path:line`,
  the explanation beneath it, then the optional suggested comment. Put a full-width heavy rule (a
  row of ~40 `━`) above each finding and one more after the last, so the list is bracketed top and
  bottom and the eye can jump between comments. For example:

  ```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ### 1 · `path/to/file.ext:42`

  Brief explanation in a sentence or two.

  Suggested comment: short line to paste, in a real reviewer's voice.

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ### 2 · `path/to/other.ext:88`

  Brief explanation, suggested comment, …

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ```

  The explanation is your note to the user and can be direct. Add **Suggested comment** only when it
  adds something beyond the explanation (nuance, or softer phrasing); if it would just restate the
  explanation, give one or the other, never both near-identical. Voice every suggested comment per
  **/use-conversational-language** (load its SKILL.md; Developer conversations, reviewer comments).
  That brevity and softness is tone, not hedging: it never lowers the evidence bar from *Grounded,
  not speculative* — stay grounded in *what* to raise, human and brief in *how* you word it.
- **Order mirrors the diff** so the user can read the PR in one window and copy-paste straight down
  in another: files in the diff's own order, ascending line number within a file, grouped by file
  when a file has several comments. This order is absolute: never reorder by a finding's perceived
  importance or severity. No severity labels, no categories. Flat and scannable.

## Boundaries

- **Read-only, one exception.** Only read-only git (`diff`, `log`, `show`, `merge-base`,
  `branch --list`, `symbolic-ref`) and read-only platform fetches, plus `git fetch` (the sole
  allowed ref update — never `git pull`). Never check out other branches, modify the working tree,
  post/reply/resolve/vote on the PR, or write files (unless the user explicitly asks to save the
  output).
- **Fetch before reviewing.** Always `git fetch` the refs under review first so the diff reflects
  the latest commits. Nothing more: no checkout of other branches into the working tree, no
  destructive ref ops, no prune, no clobbering uncommitted work.
