---
name: read-other-repos-governing-docs
description: Read a repo's governing docs (AGENTS.md/CLAUDE.md) before creating or editing files in it, whenever it isn't the session's own project — out-of-tree docs don't auto-load.
---

Governing docs auto-load only for the session's own project. Before creating or editing files in
any other repo (a rules/skills repo, a sibling checkout, a local dependency), read that repo's
governing docs — `AGENTS.md`/`CLAUDE.md` — and follow them, including the conventions they
reference: formatting configs, manifests, README entries to update in the same change.
