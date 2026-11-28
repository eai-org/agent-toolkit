---
name: explain-in-simple-language
description: Explain code, a decision, a recap, or a question to the user, or write a document a human reads, so a fluent but often non-native reader understands it on the first read. Use when explaining or asking the user anything, when writing a review, report, or brief a human reads, or when the user asks for simpler words or says they did not understand.
license: MIT
metadata:
  version: "1.5"
---

# Explain in simple language

Comprehension is the only goal of the wording: the reader understands on the first read. Defines
only the wording of text a human reads: what to say (the evidence, the parts the caller requires)
and the voice (whether the text should read as if a person typed it) stay with whatever asked for
the text; this skill decides how sentences and paragraphs are built and what you add on your own
initiative. Most agent text is already clear: change a sentence only when another wording would
raise the chance the reader understands it, and leave the rest alone.

## The reader

A competent developer, fluent in English but often not native, who did not see what you just saw:
the files, the tool output, your own reasoning. When whatever asked for the text names other
readers (a tester, a product owner), write for the least technical of them: a code name comes with
the plain name of what you saw it do. Test: would a colleague who knows the domain but just walked
up to your desk understand this?

## Rules

- **Name things concretely.** Never a stand-in for something you know and the reader doesn't: a
  reference ("both directions", "the fallback", "the second approach"), a term you coined where
  the subject already has a name ("the baseline" for the saved count), a figure of speech the
  reader's field doesn't use ("the tool plays the crowd" for "the tool simulates many users at
  once"), a general word for a specific thing ("the job cleans the data" for "the job deletes
  orders older than 30 days"), or shorthand for a case the reader didn't watch you work out ("a
  pick closes its finding"); say what it is, in their words. Short of room (a label, a title),
  cut words; never swap in a shorter stand-in.
  Lost the reader: "the class serves both directions, and the index only matters in one of them."
  Understood on the first read: "the class does two jobs, reading the file the user uploads and
  writing the one they download. The index only matters for the reading job." Longer, and better.
- **Never echo the wording of whatever instructions requested the text**: the reader never saw
  them ("the part worth a close look", not the calling skill's "files where judgment matters").
- **Only what you saw.** Context, names and reasons come from what you verified, never from what
  would make the sentence clearer; say an unchecked detail is unchecked. Clarity never beats
  accuracy.
- **Words.** Plainer words preferred; a fancy or technical term only when the reader uses it day
  to day, so one mostly found in specs or a tool's docs gets the everyday name ("the default
  case", not "the default arm" of a switch). When the everyday name says less, keep the term and
  say once what it means. Plain words for a term mean exactly what the term means ("p95: the
  time 95 in 100 requests stay under", not "how slow the slowest 5 were"). Keep a term the user
  already used or that is the subject; introduce a term before leaning on it; reuse the user's
  own words where you can.
- **Sentences.** One idea per sentence, one point per paragraph. Concrete case before general
  mechanism.
- **Depth.** Answer what was asked, at the depth it was asked, then stop: no history, alternatives,
  or adjacent facts unless the answer can't stand without them or whatever asked for the text
  requires them. The first sentence is the answer: yes or no, the number or range, the fact that
  decides it, the command for the common case, your recommendation when the user asks what to do
  or which option to take (then the why; a list of the options only when the user or whatever
  asked for the text asks for one), and in a recap what needs the reader now. Other cases and
  caveats follow only when they change what the reader does; a user checking their own reading
  gets a confirmation or a correction in a line. Prefer brevity, never at the expense of clarity:
  - if the same thing fits in fewer words without losing a detail that matters, use fewer words;
  - if the text is long anyway, lead with a simple and short TLDR, then the details;
  - if a few more words make it clearer, spend them.
- **Questions.** Before asking, give just enough context to answer, in concrete terms: what the
  choice is between and why it matters.
- **"I don't understand".** Don't restate the same sentence with more words: rebuild it from a
  concrete case and drop the term or reference that lost them. A repeat misunderstanding caused by
  the wording, after this skill applied or when it should have, is a correction of this skill or
  of the rule that triggers it: offer `self-improve` when available.
