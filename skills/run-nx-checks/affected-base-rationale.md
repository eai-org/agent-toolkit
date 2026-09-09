# Why the affected base is a freshly fetched remote-tracking ref

Nx resolves `--base` to `git merge-base <base> HEAD` and diffs from there. Its default is
`defaultBase` from nx.json (`main` when unset) — a *local* branch: stale when the work branch was
cut from `origin/<default>` without updating it (the diff then drags in everyone else's commits
between the two), and absent in fresh clones and worktrees that never checked it out (`nx affected`
errors). Fetching that branch and diffing against `origin/<default>` yields the set a pipeline
computes.

- **Never `--head`.** Nx's `parseFiles`: base + head → `git diff base head` only; base alone → that
  diff plus uncommitted plus untracked files. The skill runs on an agent's uncommitted working tree,
  and its own `--fix` and `format:write` steps edit files mid-run.
- **Narrow, guarded fetch.** Only the base branch (fast on big repos). `GIT_TERMINAL_PROMPT=0` and
  ssh `BatchMode=yes`/`ConnectTimeout` make credential prompts and dead hosts fail instead of hanging
  the forked, non-interactive run. Inside the sandbox the fetch may be denied (network proxy,
  ssh-agent socket): a stale base only costs extra tasks, never correctness, so it doesn't warrant a
  permission escalation the fork can't request anyway.
- **`NX_BASE`.** Nx reads it when `--base` is absent; a deliberate env setting must win over the
  skill's resolution.
- **Cache keys.** A task hash is project + target + configuration + sorted overrides + inputs.
  `--base`/`--head` only select projects and never enter the hash — a fresher base shrinks the set,
  it doesn't raise hits. Overrides do enter it: `--fix` and `--maxWorkers=1` make lint and test
  hashes differ from a pipeline's plain run, so only `build` (with the same `--configuration`) can
  share remote entries.
