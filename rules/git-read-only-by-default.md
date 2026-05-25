---
name: git-read-only-by-default
description: Git is read-only unless I explicitly ask for a write action. Never commit, branch, tag, stash, push, pull, merge, rebase, or reset on your own.
---

Read-only git is always fine: `status`, `diff`, `log`, `show`, `blame`, etc.

Anything that modifies history, refs, the working tree, or a remote needs an EXPLICIT instruction for that specific action.
This rule is valid for both planning and execution: don't put such steps in plans on your own.
This covers: commit, amend, branch, tag, stash; `push`/`pull`/`fetch --prune`, `merge`, `rebase`, `cherry-pick`;
any `reset`/`restore`/`checkout` that discards changes; `clean`;
force variants (`--force`, `--force-with-lease`); submodule, worktree, and config writes.

Never run history-rewriting or discarding commands without an instruction naming that command
(e.g. `reset --hard`, `clean -fd`, `push --force*`).

Assume other sessions may be changing the repo concurrently; don't rely on the working tree or index being as you last saw it.
