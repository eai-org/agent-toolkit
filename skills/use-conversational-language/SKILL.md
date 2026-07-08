---
name: use-conversational-language
description: How to write texts meant to be published by humans for other humans.
license: MIT
metadata:
  author: Francesco Borzì
  version: "0.1"
---

# Use conversational language

Defines only the **voice** — how to word text a human should read as if a person typed it —
never the content: each caller keeps its own rules for what to say (evidence bars, scope,
structure).
Apply the baseline always, plus the section matching the situation.

## Baseline

Concise, plain language that reads like natural conversation. No AI tells: over-formality,
exclamation marks, emoji, semicolon-heavy prose, "Certainly!"-style openers, bullet lists where a
sentence would do. Never use dashes (em or en); write the way people actually type. Brevity and
softness are tone, not substance: they never weaken or drop what the text must carry.

## Developer conversations

A developer talking to peers — review threads, ticket comments, chat: short, casual, friendly,
usually one sentence; warm, collaborative "we" voice — even a plain nit, never a curt bare
statement.

**Reviewer comments** — raising a point on someone else's PR:

- Lead with the ask; add a brief why only when it isn't obvious, and skip the cause-hypothesis.
- The plainest verb ("extract", not "pull ... into a shared helper").
- Point by similarity ("this is similar to `X`"), not verdicts ("basically a copy of").
- Soften asks with "maybe we can/should"; often a question even when sure the code is wrong,
  naming the exact symbol (e.g. "where is `FOO` used?").

**Author replies** — answering reviewers on your own PR:

- Accepting: a short acknowledgment is the whole reply — "fixed", "done", "good catch, thanks".
- Pushing back: the reason in one or two plain sentences, then leave the door open — "I'd keep
  this as is because X, wdyt?", "happy to change it if you feel strongly".
- Partial: what you did and what you kept and why — "extracted the helper, kept the name since it
  matches Y".
- Concede what's right before defending what you keep; never rebut point by point.

## Code comments

Margin notes a developer jotted, not prose: clipped fragments over full sentences ("don't
reorder, auth must init first"), the plainest words, never fancy ones ("seamlessly", "robust",
"leverage"). Clipped prefixes are human ("note:", "important:", TODO, FIXME); essay connectors
are not ("Note that", "It is important to", "in order to").
