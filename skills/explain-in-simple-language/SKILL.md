---
name: explain-in-simple-language
description: Explain code, a decision, a recap, or a question to the user in simple language that a fluent but often non-native developer who did not see what the agent saw understands on the first read. Use when explaining or asking the user anything, or when the user asks for simpler words or says they did not understand. Changes the wording only, never the content.
license: MIT
metadata:
  version: "0.1"
---

# Explain in simple language

Comprehension is the only goal: the reader understands on the first read. Defines only the
wording of what you say to the user; what to say (evidence, scope, structure) stays with whatever
asked for the text. Most agent text is already clear: change a sentence only when another wording
would raise the chance the reader understands it, and leave the rest alone.

## The reader

A competent developer, fluent in English but often not native, who did not see what you just saw:
the files, the tool output, your own reasoning. Test: would a colleague who knows the domain but
just walked up to your desk understand this?

## Rules

- **Name things concretely.** Never a stand-in for something you know and the reader doesn't
  ("both directions", "the fallback", "the second approach"); say what it is. Lost the reader:
  "the class serves both directions, and the index only matters in one of them." Understood on the
  first read: "the class does two jobs, reading the file the user uploads and writing the one they
  download. The index only matters for the reading job." Longer, and better.
- **Words.** Plainer words preferred; a fancy or technical term is fine unless it confuses. Keep a
  term the user already used or that is the subject; introduce a term before leaning on it; reuse
  the user's own words where you can.
- **Structure.** One idea per sentence, one point per paragraph. Concrete case before general
  mechanism.
- **Depth.** Answer what was asked, at the depth it was asked, then stop: no history, alternatives,
  or adjacent facts unless the answer can't stand without them. Prefer brevity, never at the
  expense of clarity:
  - if the same thing fits in fewer words without losing a detail that matters, use fewer words;
  - if the text is long anyway, lead with a simple and short TLDR, then the details;
  - if a few more words make it clearer, spend them.
- **Questions.** Before asking, give just enough context to answer, in concrete terms: what the
  choice is between and why it matters.
- **"I don't understand".** Don't restate the same sentence with more words: rebuild it from a
  concrete case and drop the term or reference that lost them. A repeat misunderstanding caused by
  the wording, after this skill applied or when it should have, is a correction of this skill or
  of the rule that triggers it: offer `self-improve` when available.

## Not about voice

AI traits are neither hidden nor encouraged: dashes, polish, and elegance are fine while the text
stays easy to understand. `use-conversational-language` governs the voice of text other people
read as if the user typed it (PR comments, commits, chat with colleagues); this skill governs what
the user reads in the session. The two never apply to the same text.
