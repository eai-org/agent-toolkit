---
name: maintainer-review
description: Review someone else's pull request as the maintainer deciding whether it merges — every prior comment walked, every claim verified, and nothing posted without your go-ahead.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "0.3"
---

# Maintainer review

You are the merge gate, not the author's assistant: the question is whether this ships, and the
contributor will argue back. Review in **this** session, not a subagent. A session opened for the PR
is fresh already, and staying in it keeps the diff, the comments and your findings in hand for the
argument that follows. Session already loaded with unrelated work, say so and offer a fresh one
first.

## 1. Gather

Take a PR reference on any forge and pull, through whatever tooling is connected, **all** of it
before judging: metadata (title, description, author, base and head refs, draft state, labels,
mergeability, required-check results), the diff, and every comment stream — conversation comments,
review verdicts with their bodies, and inline threads with their replies. A single "view PR" call
typically misses the review bodies and the inline threads; expect one request per stream.

Fetch here, never via a review-capture skill: those write the author's triage file and take thread
status from the forge, which step 3 re-derives against the current head.

Fetch, then diff the merge base — `<base>...<head>`, three-dot — so the target's own commits don't
read as the author's. A fork's head has no local ref; fetch the forge's PR ref for it.

Done when the head SHA, the base, the diff, the check results and all comment streams are in hand.

## 2. Follow every reference

Extract every issue and PR reference, commit sha, external link and domain identifier (a ticket key
or product entity id) from the title, the description and **every** comment, then open each,
including its own comments and the references it carries in turn, as far as the trail stays on this
PR's subject. A linked issue's description is part of the requirement; a linked PR may already have
fixed or superseded this one.

**Never take a claim as fact**, the author's no more than a reviewer's. "This breaks X" and "fixed
in the latest push" are hypotheses until the code, the data, the cited source or the current target
says otherwise.

An unticked box in the PR template is hygiene, not evidence: the sources are whatever the PR and
the opened references actually hold, and weak or off-target evidence is named as such, never called
absent.

Done when every reference on the PR, and every on-subject one it led to, has been opened or
recorded as unreachable.

## 3. Walk every comment

Build an explicit list of every conversation comment, review body and inline thread including
replies. For each, record what was raised, whether it was answered, and **whether it still applies
at the current head and the current target**. A thread the target has since fixed counts as
answered, by the commit and file that fixed it; an anchor that merely drifted onto changed lines has
not been answered by anything.

Never skip one for looking resolved, old or minor, and never batch them away. Bot reviewers count:
their findings are often the only ones on record, and an author's "no, addressed above" is a claim
like any other. This walk overrides any read-comments-lightly or ignore-bots default in the skill
loaded next.

An approval predating the current head approved a different changeset — say so rather than counting
it.

Done when every item carries, with its evidence, whether it was answered and whether the concern
still stands or no longer applies — answering one never settles the other.

## 4. Read the diff

Load and follow [review-code-assistant](../review-code-assistant/SKILL.md) on the pinned changeset
for its lenses, its grounded-evidence bar, and the project's own convention docs run as a checklist.
Reframe its mandate as the merge gate — does anything here block the merge. Its comment handling,
its branch-freshness rule and its read-only boundary are superseded by this skill: the changeset
stays the step-1 head SHA, so the diff pass and the comment walk judge the same code.

Done when the diff pass has returned its findings, possibly none.

## 5. Fresh eyes over the findings

Load [fresh-eyes-review](../fresh-eyes-review/SKILL.md), giving it the diff as the changeset, the
title, description and linked issue as the intent, and **your draft findings as the artifact to
check**. A clean verdict is an artifact too, and the one most worth checking. Its mandate here: is
each finding grounded in the diff, is anything claimed that the code does not support, is anything
obvious missed. A cheaper or faster model is enough for this pass when the harness offers one.

Drop what it refutes, fix what it corrects, and report what it raised that you chose not to adopt.

Done when every draft finding was kept, dropped, or knowingly kept against the reviewer's
objection — with none, when the clean verdict came back unchallenged or gained a finding.

## 6. Report

In chat, no file. The reader sees the tail first, so the **scannable** part goes last.

**Detail first.** Every finding with its `path:line` and evidence, then the comment walk. Facts, not
restatement; no item outgrows a short paragraph. Name what was checked against what, and what wasn't
and who closes it: a review that never ran the code says so, and names what the author should test,
including the side effects a fix for X reaches in Y.

**Summary last** — it has to survive a glance, in this order:

- the verdict: does it block the merge, and what stands in the way;
- one line per finding and per walked comment, mirroring the detail's order, each with its
  `path:line` (or the comment's author and date), the claim in a clause, and its position —
  blocking, non-blocking, answered, no longer applies;
- anything still unverified and who closes it, named not restated;
- the one recommended next action and what it waits on.

A table is usually tightest for that list; evidence stays above, never repeated here.

Done when the closing summary carries every item above, in order, each finding and walked comment
among them with a stated position.

## Acting on the PR

Nothing is posted, approved, labelled, merged or pushed without a **separate** go-ahead naming that
action, and re-read the head SHA then: moved since the review, the verdict covers a changeset nobody
reviewed, so say so rather than act. Drafting is not posting, and a request to act is not approval
of the wording: show the text, then wait. Project etiquette — which labels, which checks, who may
merge — comes from the repo's own governing docs, not from here.

- **Comments** — the concern, the location, the suggested change, nothing else. No preamble, no
  recap of the PR, no praise padding. Invoke
  [use-conversational-language](../use-conversational-language/SKILL.md) for the wording.
- **Approvals** — plain, with an empty body. Anything worth saying is a separate comment.
- **Fixes**, only when asked — on the contributor's own branch, never a local copy nobody sees. The
  go-ahead reaches that branch's push and no further **on the PR**; putting your own checkout back
  belongs to the fix, not to a new go-ahead. A clean working tree first: uncommitted work follows
  the checkout and ships to the contributor under their name. Stash what doesn't belong, or confirm
  it as local-only and let the by-path commit below leave it out. Then add the head's remote when it
  is a fork (a same-repo head needs none), fetch, check out the branch, write the fix, commit its
  files by path, push fast-forward only, and return to the branch you started on, popping the stash.
  Never rebase, never force-push, never amend a pushed commit: rewriting a contributor's published
  history takes another force push to undo, and it is not yours to rewrite.

  Leave the target unmerged unless the fix itself needs it: the push fast-forwards either way, and a
  merge commit on a linear-history branch takes the force push just forbidden to remove. Needed and
  conflicting, hand back rather than resolve someone else's conflicts — mid-merge the by-path commit
  is refused anyway.

## Boundaries

Read-only git plus `git fetch`, and no writes to the working tree — until a fix is explicitly
authorised, the sole exception. Output is chat text; write a file only if asked.
