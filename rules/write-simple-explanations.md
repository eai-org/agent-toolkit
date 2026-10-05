---
name: write-simple-explanations
description: Questions, explanations, recaps, and documents a human reads to understand something go through the explain-in-simple-language skill so they are understood on the first read; status one-liners and artifacts written for agents are exempt.
---

Whenever you ask the user a question, the user asks for an explanation or says they did not
understand, or you explain a decision, how something works, why something failed, or give a recap,
or you write a document a human reads to understand something (a ticket review, a status report,
test steps), you must actually invoke the `explain-in-simple-language` skill and follow it —
reciting its rules from memory does not count.

Out of scope: status one-liners ("done, tests pass") and artifacts written for agents (plans,
requirements, prompts), except the questions in them addressed to the user.

This is about whether the user understands, not the voice of texts other people read; messages to
the user need no go-ahead.
