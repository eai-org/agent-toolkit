# Install with agentwheel

[agentwheel](https://github.com/NestDevLab/agentwheel) installs this repo's rules **and** skills
into your agent and keeps them in sync across Claude, Codex, Copilot, and other runtimes, from
one source. This repo ships an [`openpack.json`](../openpack.json) manifest, so it's a first-class
OpenPack package (requires agentwheel ≥ 0.9.0). Run it from where you want it installed (`~` for
user level, or a project root):

```sh
npx agentwheel install github:eai-org/agent-toolkit --adapter claude
```

Swap `--adapter claude` for `codex`, `copilot`, etc. to target other agents. For dry runs,
tracking updates, named targets, profiles, or more controlled `add` → `plan` → `install` flows,
see the [agentwheel documentation](https://github.com/NestDevLab/agentwheel).

Only want specific pieces instead of everything? Select them by `<type>/<name>`, for example one
skill plus one rule:

```sh
npx agentwheel install github:eai-org/agent-toolkit --adapter claude \
  --select skills/run-nx-checks,rules/no-nonsense-comments.md
```

`--select` is repeatable or comma-separated.

The manifest also marks hard internal dependencies. For example, selecting
`skills/compact-skill-creator` also installs `skills/compact-docs-writer`.
