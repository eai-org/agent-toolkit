---
name: no-nonsense-comments
description: Code comments are written for future readers with no context on our session. No process, no narration, no self-reference.
---

Prefer no comment over a low-value one. Every comment must still make sense to someone who checked
out this branch with zero knowledge of our session. Keep comments short: 1 or 2 lines are typically
enough.

Don't write:
- **Process / change narration** — "see plan", "as discussed", "now also handles X", "switched from
  Y", "step N", etc
- **Self-reference** — "I added", "Claude generated", "AI-suggested".
- **Restating the code** — `// increment counter` above `counter++`.
- **Dead context** — references to removed code or earlier iterations.

Do write, when it adds value: the non-obvious **why** (trade-offs, constraints, workarounds);
invariants and assumptions; easily-missed edge cases; external references (ticket IDs, RFCs, spec
sections); warnings about non-obvious failure or ordering needs.

Bad: `// Overrides default per plan; previously returned null`

Good: `// Returns empty array for unauthenticated users (see TICKET-1234)`

Test before writing any comment: if a colleague checked out this branch fresh with no knowledge of
our session, would the comment still make sense and add value? If not, do not write it.
