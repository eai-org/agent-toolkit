---
name: git-read-only-by-default
description: Git writes need explicit user scope; routine PR branch commits and pushes are allowed.
---

Read-only git is always fine: `status`, `diff`, `log`, `show`, `blame`, etc.

Git write actions are allowed when they are clearly inside the user's requested workflow and scope.
For example, if the user asks to create a PR, update a PR branch, fix review comments, or resolve
PR conflicts, the agent may create a branch, commit the scoped changes, and push that PR branch.

Ask before Git writes that are ambiguous, cross-branch, outside the requested task, or likely to
surprise the user. This includes unrelated commits, broad staging, merges from unclear bases,
publishing to an unexpected remote, or changing repository config.

Never run destructive, history-rewriting, or discard operations without an instruction naming that
operation, such as `reset --hard`, `clean -fd`, `push --force*`, `rebase`, or a checkout/restore
that would discard work.

Assume other sessions may be changing the repo concurrently; don't rely on the working tree or index
being as you last saw it.
