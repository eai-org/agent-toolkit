---
name: write-realistic-texts
description: Texts other people will read follow the use-conversational-language skill, and the ones the rule names need the user's go-ahead on their wording before publishing; replies to the user in session are exempt.
---

Whenever writing text that other people will read as if the user wrote it — commit messages,
PR descriptions, review comments, code comments, chat messages or questions for colleagues, and
similar — you must actually invoke the `use-conversational-language` skill and follow its rules
— reciting them from memory does not count.

Replies to the user in the current session are private agent-user communication, out of scope
however conversational they sound.

Documentation (README and similar) is out of scope for the voice rule: written prose conventions
apply there, not conversational voice.

Agent-facing texts (plans, analyses, specs, skills, rules) are exempt; there, completeness and
unambiguity beat brevity.

Publishing any of these needs an EXPLICIT go-ahead on the concrete wording first: PR and issue
comments, PR descriptions, review bodies, release notes, chat messages, wiki and tracker pages,
commit trailers crediting other people.

Naming the action does not approve the wording: "approve and add the label", "comment and close"
authorize those actions and nothing more. Draft it, show it, wait. Other named actions proceed
meanwhile unless the instruction ordered them after the text or the action itself publishes it, so
"comment, then approve and merge" holds the whole chain at the comment.

Submit PR approvals with an empty body; anything worth saying goes as a separate comment. A
go-ahead covers the wording it was given for, never the next text. Never write opinions,
verdicts, or a review in the user's voice that the user did not ask for.
