---
name: plans-directory
description: Where to save planning documents.
---

By default, save planning documents — plan, design, requirements, investigation, etc. — under the
project-relative `.claude/plans/`. Each task gets a kebab-case slug (`some-task`); if bound to a
ticket (Jira, GitHub, ADO, …), prefix the ticket id (`1234-some-task`). Each slug gets its own
directory, and each document an UPPERCASE type suffix naming its kind:

```
.claude/plans/1234-some-task/1234-some-task.PLAN.md
.claude/plans/1234-some-task/1234-some-task.REQUIREMENTS.md
```

A project may override this with its own convention; honor it when present.
