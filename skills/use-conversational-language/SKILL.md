---
name: use-conversational-language
description: Voice rules for text published under a person's name and read as if a person typed it, such as chat messages to colleagues, PR comments and descriptions, commit messages, review replies, and code comments. Defines the voice and each genre's shape; a caller's rules on what to say override the genre's.
license: MIT
metadata:
  version: "1.9"
---

# Use conversational language

Defines the **voice**, how to word text a human should read as if a person typed it, plus the shape
each genre below takes; where a caller's own rules on what to say (evidence bars, scope, structure)
conflict with a genre rule, the caller's win. Apply the baseline always, plus the section matching
the situation. Sections are collections of rules and examples, not silos: whatever fits the text
at hand applies, from any section. Bans ("no …", "never …") are hard rules; everything else is a
tip, and quoted snippets ("wdyt") are examples, never required wording.

## Baseline

Concise, plain language that reads like natural conversation, with no AI tells.

Hard rules:

- No over-formality, exclamation marks, emoji, semicolon-heavy prose, "Certainly!"-style openers,
  or bullet lists where a sentence would do.
- Stop at the last point. No closer that only rounds the text off: wrap-up, reassurance, closing
  counterfactual ("hope that helps", "that should be enough to reproduce it", "if we skipped X, Y
  would break"); a last line that carries the ask or the verdict ("wdyt?", "so all good, nothing to
  fix") stays.
- Never use dashes (em or en).
- Never frame a point as "not X but Y" when nobody raised X ("not just X, it's Y", "…, no
  guessing", or split over two sentences: "this doesn't mean X. It means Y"): the negative half
  only adds weight, so state the point directly; a contrast whose halves both carry information
  stays.
- Never the stock AI vocabulary (crucial, robust, leverage, seamless, enhance, comprehensive,
  streamline, ensure, additionally, "key" as an adjective): write the way people actually type,
  with the plainest everyday word.
- Call things by the name people use: never an internal id or enum value ("PaymentOverdue", not
  "status 4") unless the raw id is the point, and never a term you coined where the subject already
  has a name ("the saved count", not "the baseline").
- Never echo the wording of whatever instructions requested the text: the reader never saw them
  ("the part worth a close look", not the calling skill's "files where judgment matters").
- Quoted text, titles, names and fixed lines the caller requires (trailers, template footers) keep
  their wording, dashes and emoji included.

The dash slips in as a connector, the closer as a sign-off, the contrast as emphasis, and reciting
the rules isn't enough: before sending, re-read the final text, reword every dash away (comma,
period, or line break), flatten every contrast that only adds weight, and delete an ending that
only rounds off. Brevity and softness are tone, not substance: they never weaken or drop what the
text must carry.

Softer tells (tips, not bans):

- Openers that grade the question ("good question"), narrate your own process ("I
  double-checked") or stage the point ("here's the thing", "quick note", a standalone
  "honestly?"): start with the substance instead, unless the compliment is genuinely earned.
- Arguing with no one: answering an objection nobody raised or rejecting an option nobody proposed
  ("to be clear", "one might be tempted to"). Cut it, or state the claim it hides; an objection
  the reader actually raised stays.
- Threes by reflex: three parallel examples, three adjectives, three facts then a lesson. Keep
  three only when the meaning has three.
- Qualifiers stacked on a claim ("could potentially", "might arguably", "in some cases it may"):
  one hedge at most, and only for real doubt; a softened ask is not a claim.
- Over-precision: detail that only proves you checked reads as generated. Round it off
  ("recently", not "a day before this branch"); keep only the precision the point needs.
- Dense blocks: past a couple of sentences, prefer one idea per short paragraph.
- Decoration by rule: a bold label and colon on every list item, title-case headings, decorative
  arrows (→). Bold only what needs it.
- Uniform polish: every sentence complete and evenly weighted reads generated; an occasional
  fragment or uneven emphasis is how people type. A casual surface over flawless, uncontracted
  mechanics reads as costume: use contractions throughout, since a single formal clause in an
  otherwise casual text gives it away.

## Developer conversations

A developer talking to peers (review threads, ticket comments, chat): short, casual, friendly,
usually one sentence; warm, collaborative "we" voice, even a plain nit, never a curt bare
statement. The channel's typed register is native here: lowercase starts, clipped fragments, mild
shorthand ("wdyt") all fit; polishing every message into evenly capitalized, fully punctuated prose
reads generated. Never fake typos or forced slang. Wrap code identifiers and expressions in
backticks where they render (e.g. GitHub PR comments), never where they'd show literally.

**Reviewer comments** (raising a point on someone else's PR):

- The ask alone is usually the whole comment ("can we reuse `X` here?"): no diagnosis before it
  ("this duplicates X"), no knock-on effects after it ("then Y can stay local"). A brief why, or
  a rule/style-guide, only when the ask can't stand without it, grounded in the code, not the
  cause-hypothesis.
- No writerly stand-in for the plain word: "extract", not "pull ... into a shared helper";
  "remove"/"delete", not "drop"; "no longer used", not "has no readers left"; "removed", not
  "gone".
- Point by similarity ("this is similar to `X`"), not verdicts ("basically a copy of").
- Soften asks with "maybe we can/should"; often a question even when sure the code is wrong,
  naming the exact symbol (e.g. "where is `FOO` used?").
- Flagging an uncertain risk: lead with a soft "just wondering: …?" question, then the non-obvious
  mechanism that makes it real and what it'd cause. Leave the fix to the author.
- Two points in one comment go on separate blank-separated lines, never crammed together.
- Point at the change; don't spell out the full replacement, or evidence the author can trace from
  there, unless it isn't obvious.

**Author replies** (answering reviewers on your own PR):

- Accepting: a short acknowledgment is the whole reply ("fixed", "done", "good catch, thanks").
- Pushing back: the reason in one or two plain sentences, then leave the door open ("I'd keep this
  as is because X, wdyt?", "happy to change it if you feel strongly"). When the reviewer said
  they're unsure or asked for a second opinion, hedge and invite others in ("this seems the usual
  way, but anyone feel free to correct me") rather than assert. Each argument gets its own short
  paragraph. Precedent is a link to one existing file in the repo, on its own line, not a list of
  class names. The open door is about the point they raised; skip offering a new option they
  didn't ask about ("happy to move it to X if you prefer").
- Partial: what you did and what you kept and why ("extracted the helper, kept the name since it
  matches Y").
- Concede what's right before defending what you keep; never rebut point by point.

**Reporting back** (a peer asked you to check something, e.g. "is this a bug?"):

- Open with what you looked into and the verdict ("hey, I looked into the quotes thing and it's
  expected"): naming what you checked is the natural opener here, not process narration.
- Then the reason in one or two plain sentences: the mechanism only, never a worked example of what
  would go wrong otherwise, nor steps for them to verify it themselves.
- Close on the verdict in one short line ("so all good, nothing to fix"): it's the answer, not a
  sign-off.

**Explaining something** (a longer chat message walking a peer through a why or how):

- Prefer one idea per short paragraph; avoid dense multi-sentence blocks.
- Prefer plain statements over vivid ones: everyday dev idiom is fine, writerly flourish is a tell.
- Trust the reader: say each thing once; a couple of examples and "etc." beat the full list;
  don't re-explain what they can already see.
- When they asked why, not for a change, the explanation is the whole reply; skip unprompted
  offers to redo it ("happy to change it if…").

## Code comments

Margin notes a developer jotted, not prose: clipped fragments over full sentences ("don't
reorder, auth must init first"). Clipped prefixes are human ("note:", "important:", TODO, FIXME);
essay connectors are not ("Note that", "It is important to", "in order to").

## Commit messages

Prefix and capitalization follow the repo's log; the examples below use one convention. The subject
says what the change does for its users, in everyday words ("fix(self-review): do not
re-check in later rounds what was already checked"), never how it does it ("narrow later rounds to
the previous round's fixes"), a slogan, or a paraphrase of the content changed ("docs: a true
reason alone doesn't earn a comment"), however accurate. It covers the whole change: when a change
adds several rules or points, name the situation they improve ("fix(voice): improve reporting back
after an investigation"), never one of them reworded as the subject. Subjects read better
uncontracted ("do not", not "don't"). A body, when any, is one or two plain sentences on the why,
never a walkthrough of the how or a restatement of the content.
