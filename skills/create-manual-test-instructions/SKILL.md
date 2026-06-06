---
name: create-manual-test-instructions
description: Turn a ticket or requirements document into a concise QA manual-test file a non-author can follow. Invoke manually only.
disable-model-invocation: true
context: fork
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.0"
---

# Create manual test instructions

Turn a ticket or a refined requirements document into a concise QA manual-test file.

Read the document (and, where needed for accurate navigation, the code it cites). Write the
manual-test file in the **same directory**, naming it by replacing `.REQUIREMENTS` or `.TICKET` with
`.MANUAL-TEST` (e.g. `FOO.REQUIREMENTS.md` → `FOO.MANUAL-TEST.md`); if the input follows neither
convention, append `.MANUAL-TEST` before `.md`. If there is no file (pasted text), follow the
project's planning convention for the location and confirm the slug and path with the user.

The file must be followable by someone **unfamiliar with the ticket** — short but complete. Four
parts:

1. **What changed** — 1–2 sentences: the feature and the user-visible difference.
2. **How to get there** — concrete navigation to the affected area (entry point, page/screen name,
   any prerequisite state).
3. **Before vs after** — how the area behaved before, how it should behave now.
4. **What to verify** — checklist of behaviors to confirm, including edge cases (empty values,
   multiple items, boundaries) where relevant.

Do not modify any source files; the only file you write is the manual-test document.

When done, state the manual-test file's **project-relative path**.
