# Installing the rules

## How rules work

Rules are always-on behavior policies. While a skill loads into context only when invoked or
matched to the task, every installed rule is auto-loaded into every session and changes how the
agent works on every task — e.g.
[`git-read-only-by-default`](../rules/git-read-only-by-default.md) blocks all git writes unless
explicitly instructed. That's why the rules are opt-in and never installed implicitly with the
skills.

Auto-loaded rule directories (like `~/.claude/rules`) are mostly a Claude Code feature; agents
without one take a single global `AGENTS.md` instead, so only the skills apply to them.

## The install script

From the repo root:

```sh
./install-opinionated-rules.sh
```

It mirrors [the skills install](./install-skills.md): the same two symlink layers
(`~/.agents/rules` → `~/.claude/rules`), converging re-runs, and `--agents-dir`, `--rules-dir`,
and `--force` options. Rule links left by older `./install.sh` runs stay intact but are updated
only by this script — run it after `git pull` to keep them in sync.

## Linking rules by hand

You can also link individual rules, through the same two layers:

```sh
mkdir -p ~/.agents/rules ~/.claude/rules
ln -s "$(pwd)/rules/no-nonsense-comments.md"  ~/.agents/rules/
ln -s ~/.agents/rules/no-nonsense-comments.md ~/.claude/rules/
```

## Other agents

For an agent that does have an auto-loaded rules directory, wire it with:

```sh
./install-opinionated-rules.sh --rules-dir <agent-rules-dir>
```
