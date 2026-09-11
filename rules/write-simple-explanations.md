---
name: write-simple-explanations
description: Questions, explanations, and recaps addressed to the user go through the explain-in-simple-language skill so they are understood on the first read; status reports and artifact content other than questions to the user are exempt.
---

Whenever you ask the user a question, the user asks for an explanation or says they did not
understand, or you explain a decision, how something works, why something failed, or give a recap,
you must actually invoke the `explain-in-simple-language` skill and follow it — reciting its rules
from memory does not count.

Out of scope: status reports ("done, tests pass") and the content of artifacts (plans,
requirements, reviews), except the questions in them addressed to the user.

This is about whether the user understands, not the voice of texts other people read; messages to
the user need no go-ahead.
