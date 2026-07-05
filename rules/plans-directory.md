---
name: plans-directory
description: Where to save planning documents.
---

Save planning documents — plan, design, requirements, investigation, etc. — in the project's
planning directory: the one named in its governing docs (AGENTS.md, …) or already unambiguously in
use. When none is evident, fall back to the project-relative `.claude/plans/`.

Each task gets a kebab-case slug (`some-task`); if bound to a ticket (Jira, GitHub, ADO, …), prefix
the ticket id (`1234-some-task`). Each slug gets its own directory, and each document an UPPERCASE
type suffix naming its kind:

```
.claude/plans/1234-some-task/1234-some-task.PLAN.md
.claude/plans/1234-some-task/1234-some-task.REQUIREMENTS.md
```
