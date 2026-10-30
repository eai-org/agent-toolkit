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
(`~/.agents/rules` → `~/.claude/rules`), converging re-runs, the same `--agents-dir`,
`--rules-dir`, `--force`, `--no-auto-update` and `--auto-update` options, and the same daily
[self-update hook](./auto-update.md) when Claude Code is detected. On
[Windows](./install-skills.md#windows) the rules do not get the junction fallback the skills do,
since each rule is a single file, so updating means re-running this script with `--force`. Rule
links left by older `./install.sh` runs stay intact but are updated only by this script — run it
after `git pull` to keep them in sync.

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

## Enforcing no-ai-attribution in Claude Code

[`no-ai-attribution`](../rules/no-ai-attribution.md) keeps the agent from writing AI attribution
into commits and PRs; Claude Code can also be set not to add it at all, in
`~/.claude/settings.json`:

```json
{
  "attribution": {
    "commit": "",
    "pr": "",
    "sessionUrl": false
  }
}
```

The empty strings drop the co-author trailer and the PR footer, and `sessionUrl` `false` drops the
`Claude-Session` trailer and session link that cloud and Remote Control sessions add. Cloud
sessions don't read this file; for a cloud session on one repository, outside a
[claude.ai project](https://code.claude.com/docs/en/claude-projects), commit the same block to that
repository's `.claude/settings.json`, where it applies to everyone working in it.
`"attribution": false` covers all three in one value but needs Claude Code v2.1.281 or later; older
builds reject the whole settings file that holds it. The deprecated `includeCoAuthoredBy` key is
ignored once `commit` or `pr` is set. Key names and versions follow the
[settings reference](https://code.claude.com/docs/en/settings-reference#attribution).
