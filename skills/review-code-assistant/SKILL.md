---
name: review-code-assistant
description: Assist a human reviewing a pull request or branch locally, read-only and never posting.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "1.13"
---

# Review code assistant

Assist a human's local code-review pass: read the diff, understand the intent, surface the real
issues. You suggest candidate comments; the human decides what to post.
Single-pass and lightweight. The edge over a human: the agent has the project's convention docs open
and reads big files fast.

## Resolve what to review

Accept input flexibly; a PR link is optional:

1. **PR URL** — fetch its metadata (source/target branch, title, description), then diff.
2. **One branch** ("review branch xxxx") — diff it against the auto-detected target.
3. **Two branches** ("review xxxx against yyyy") — explicit source and target.
4. **Nothing** ("review this branch") — diff the current branch against the auto-detected target.
   A detached HEAD → ask which branch is under review; an empty diff → probably a wrong target
   (typical: a fork's default branch already holding the commits), say so and ask.

(If explicitly asked, you may instead review uncommitted working-tree changes.)

**Diff base:** always a three-dot merge-base diff, `git diff <target-ref>...<source-ref>`, so it
matches exactly what the platform shows as the PR with no noise from commits that landed on target
after the fork. No common ancestor: usually a shallow clone or a wrong target. Deepen with
`git fetch --unshallow` and retry, else ask; never diff two-dot against the target.

**Branch freshness:** always `git fetch` first — never `git pull`: the diff needs no checkout or
working-tree update. Then diff each branch's freshest ref, stating which you used and its SHA: the
remote-tracking ref when the branch is on a remote and the local ref isn't ahead of it; the local
ref when the branch exists only locally or carries unpushed commits (never silently review a stale
pushed state); for a fork PR's source, absent from `origin`, the fork remote or the platform's PR
ref (e.g. `git fetch origin pull/<N>/head` on GitHub). If a fetch fails or a ref can't be found,
say so and ask how to proceed rather than review stale or wrong refs.

**Target auto-detection** (when not supplied and not from a PR link), in order:
1. The default branch of the `upstream` remote when one exists (fork workflow), else of `origin`,
   via `git ls-remote --symref <remote> HEAD`, never the often-absent local
   `refs/remotes/<remote>/HEAD`.
2. That failing (e.g. offline), check which usual candidates exist (`main`, `master`,
   `develop`/`development`); exactly one match wins.
3. Multiple matches or any ambiguity → ask, never guess.

A PR link always overrides auto-detection (its target comes from the PR metadata; PRs are not always
against the main branch). Always state which target was chosen so the user can correct it.

## Enrich from the PR link

When a URL is given, identify the platform from its host and fetch through whatever is connected
(a GitHub tool, an Azure DevOps tool, etc.) — use the intent, not a fixed tool. No link given and
no tool: review the local diff and say the PR context was not read. A link given but no tool to
read it: ask for the branches rather than guess them.

- Use the title and description to understand intent.
- Follow linked issues and PRs: a linked issue's description is part of the intent, and a linked
  PR may have superseded or already fixed it.
- Treat claims in the description and comments ("fixed in the latest push", "this breaks X") as
  hypotheses until the diff or code confirms them.
- Read existing human comments only lightly: to avoid duplicating feedback already raised, and
  to spot claims to verify.
- Ignore bot and CI comments.

## Review lenses

Lenses a human applies, not a checklist to fill: report only what you find; a lens that finds
nothing produces no output.

- **Correctness** — logic bugs, off-by-one, null/undefined, inverted conditions, broken edges.
- **Consistency** — matches the surrounding patterns and naming.
- **Duplication and bad practices** — relevant repeated logic that should reuse something, and
  general bad practice. Relevant, not "these two lines look vaguely similar".
- **Intent mismatch** — does the diff actually do what the title and description claim; anything
  missing, and a title that oversells or hides a behaviour change.
- **Still needed** — the target may have gained the same fix since the branch forked; a change
  that no longer applies is itself a finding. Check with
  `git log --oneline <merge-base>..<target-ref> -- <changed paths>` and read any hit that touches
  the same logic.
- **Realistic risk** — security or performance footguns that genuinely apply here, not an audit.
- **Leftovers** — debug prints, commented-out code, stray TODOs, accidentally committed files.

Before reviewing, load the project's own convention docs (CLAUDE.md/AGENTS.md, any relevant
codestyle/contributing docs, and the project's PR-review rules doc when one exists, default
`.agents/docs/pr-review-rules.md`), then run them as a checklist, not as background reading,
against every changed file and the submission itself (title, description, linked issues). A clear
violation is a first-class, citable comment and the skill's edge over a human, easiest to miss in
new test files (test-structure conventions) and on new class members (visibility and naming).
State which ref's docs the checklist ran against. When the target ref's governing docs differ from
the checkout's (`git diff <target-ref> -- AGENTS.md CLAUDE.md` and the docs they reference), say so
and, on a standalone run, use the target's copy via `git show <target-ref>:<path>`; under
maintainer-review its step 1 rule applies.

## Grounded, not speculative

The core rule. A comment may exist only when it points to concrete evidence of one of:

1. **The code is demonstrably wrong** — you can name the actual failure (this input throws, this
   condition is inverted, this loses the value).
2. **It breaks a documented project rule** — you can cite the convention (a doc, or an established
   pattern visible in the surrounding code).
3. **It is a concrete, behavior-preserving simplification** — needless indirection or duplication
   you can collapse with certainty, naming the exact redundancy and the smaller form. (E.g. a
   non-exported const in the class's own file that only aliases one class field is collapsible, or
   the same expression repeated across a template, collapsed into one named derivation; an exported
   or separate-file const is fine, it may be reused elsewhere.)

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
generated or binary file committed by accident). Nothing to flag there → say nothing about them.

**Zero comments is a valid and common outcome.** Finding few or none is success, not failure. Never
pad to look thorough. No praise, no restating what the code does, no test-coverage lectures, nothing
on lines the PR did not touch.

## Output

Local text only; write no file unless the user later asks to save it.

Before writing anything addressed to the user — questions included, a **Suggested comment**
excepted — actually invoke **/explain-in-simple-language** and follow it — reciting its rules from
memory does not count. Not installed: plain words, one idea per sentence, a short TLDR opening a
long text, and no "here" or "this call" standing in for something the user hasn't seen.

- Lead with one short sentence recapping what the PR does and naming the reviewed SHA, to show the
  change was understood.
- Then the comment list, or a one-line `Looks good, no comments.`
- Say plainly what you verified and what you could not (e.g. behaviour only testable at runtime),
  inside the finding when it concerns only that one, else in one line right after the recap, where
  any changed file you did not read is also named.
- Each item: a `###` heading holding its sequential finding number and the clickable `path:line`,
  the explanation beneath it, then the optional suggested comment. Put a full-width heavy rule (a
  row of ~40 `━`) above each finding and one more after the last, so the list is bracketed top and
  bottom and the eye can jump between comments. One issue per finding: an unrelated second point
  on the same lines gets its own. For example:

  ````
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ### 1 · `path/to/file.ext:42`

  Explanation.

  Suggested comment:

  ```
  short line to paste, in a real reviewer's voice
  ```

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ### 2 · `path/to/other.ext:88`

  Explanation, suggested comment, …

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ````

  **The explanation** is your note to the user and can be direct. The user must be able to judge
  the finding from it without opening the code. It holds:

  - **Where, by name** — the files, services and values involved. When the PR has several similar
    places, say which ones the finding covers and which it doesn't.
  - **Expected next to actual** — what the ticket, rule or correct behaviour requires, beside what
    the code does. Quote the ticket or rule, never paraphrase it.
  - **The consequence** — what goes wrong and for whom, or that nothing breaks and it is only a
    cleanup. With no severity labels, this is how the user weighs the finding.
  - **The tool behaviour it rests on**, in a sentence or two, when the finding holds only because
    of how a specific tool or subsystem behaves (how a mock server picks a mapping, which
    environments run a seed step). A judgement call: skip what any developer on the project knows.
  - **The fix as code**, current next to replacement, when it is a few lines you are certain of
    and no suggestion block (below) already carries it.

  Length follows the finding: a stray debug print takes one sentence, and nothing goes in that the
  user doesn't need to judge it. A long explanation opens with a TLDR; the output as a whole gets
  none, the recap is its opening. Use a table or an expected/actual code pair where it shows a
  difference or a data flow more clearly than prose.

  Add **Suggested comment** only when it adds something beyond the explanation (nuance, or softer
  phrasing); if it would just restate the explanation, give one or the other, never both
  near-identical. It makes one point: for a mismatch, what the ticket or rule says, what the code
  does, then the question. When the fix is itself a snippet — most often an explanatory code comment
  — the suggested comment can be that snippet, ready to paste, rather than prose asking the author
  to write it; where a human reviewer would realistically post the platform's one-click suggestion
  block (the PR's platform has them, the replacement is small and certain), give that block, its
  label above the fence naming the exact lines to anchor it on
  (`Suggested comment, on lines 40-44:`). Give each **Suggested comment** as a fenced block holding
  exactly what gets pasted, never a blockquote (`>` prefixes travel with the copy); when the comment
  holds a fence, make the outer one longer, never indent or escape the inner fence. Before writing
  any **Suggested comment**, actually invoke **/use-conversational-language** and follow it —
  reciting its rules from memory does not count.
  Not installed: write plain prose instead, no dashes and no AI tells.
  That brevity and softness is tone, not hedging: it never lowers the evidence bar from *Grounded,
  not speculative* — stay grounded in *what* to raise, human and brief in *how* you word it.
- **Order mirrors the diff** so the user can read the PR in one window and copy-paste straight down
  in another: files in the diff's own order, ascending line number within a file, grouped by file
  when a file has several comments. This order is absolute: never reorder by a finding's perceived
  importance or severity. No severity labels, no categories. Flat and scannable.

## Boundaries

- **Read-only, one exception.** Only read-only git (`diff`, `log`, `show`, `merge-base`,
  `branch --list`, `symbolic-ref`, `ls-remote`) and read-only platform fetches, plus `git fetch` of
  the refs under review, always run first so the diff reflects the latest commits (`--unshallow`
  included; never `git pull`, never `--prune` or any other destructive ref op). Never check out
  other branches, modify the working tree or clobber uncommitted work, post/reply/resolve/vote on
  the PR, or write files unless the user explicitly asks to save the output.
