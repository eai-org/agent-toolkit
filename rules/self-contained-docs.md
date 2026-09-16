---
name: self-contained-docs
description: Planning and design documents, and prompts handing work to another session, must be concise and executable by a fresh agent session with no prior context.
---

When I ask for a document that captures investigation, design, requirements, or implementation
plans, make it concise and effective.

It must contain enough information for a fresh agent session with a clean context to pick it up and
execute it, without referring back to the original ticket or any prior conversation.

At the same time, do not include information that does not directly contribute to executing or
understanding the task. Concision matters as much as completeness.

A prompt or brief handing work to another session is such a document: actually invoke the
`prepare-prompt` skill to write it — reciting its rules from memory does not count. Not installed:
hold the prompt to the rules above.
