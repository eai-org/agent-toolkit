# Installing the skills

The one-command quick install is in the [README](../README.md#how-to-install-the-skills); this doc
covers how it works and the alternative install methods.

## Install via symlinks

[`install.sh`](../install.sh) symlinks every skill from this repo in two layers:

1. `~/.agents/skills` — the canonical, agent-neutral location — gets one link per skill
   directory, pointing into the repo;
2. your agent's own directory — `~/.claude/skills` by default — gets links pointing at the
   `~/.agents` entries.

The skills become available in all your projects without copying files around, and every agent
wired to `~/.agents` shares the same set.

Re-running converges: correct links are left alone, links from the old direct layout are
re-pointed, and broken links owned by this repo are pruned — so `git pull && ./install.sh` always
brings an existing install up to date.

First clone the repo (or your own fork):

```sh
git clone https://github.com/eai-org/agent-toolkit.git && cd agent-toolkit
```

Then you can run:

```sh
./install.sh
```

Options:

```sh
./install.sh --agents-dir DIR        # custom agent-neutral location (default: ~/.agents)
./install.sh --skills-dir DIR        # agent skills dir to wire (e.g. a project's .claude/skills)
./install.sh --force                 # overwrite real files/dirs and foreign symlinks
./install.sh --help
```

You can also skip the script and symlink just the ones you want by hand, through the same two
layers:

```sh
mkdir -p ~/.agents/skills ~/.claude/skills
ln -s "$(pwd)/skills/run-nx-checks" ~/.agents/skills/
ln -s ~/.agents/skills/run-nx-checks ~/.claude/skills/
```

Start a new session and run `/context` to confirm everything is loaded. Skills apply at the user
level (all projects); to scope them to one project, wire that project's directory instead, e.g.
`./install.sh --skills-dir <project>/.claude/skills`.

## Other agents

Other agents like OpenCode discover Claude-style skills in `~/.agents/skills` natively, so the
default install already covers them. For one that doesn't, point its skills directory at
`~/.agents/skills` — or run the script again with the agent's own directory:

```sh
./install.sh --skills-dir <agent-skills-dir>
```

## Install via skills.sh

You can also use the [skills.sh](https://skills.sh/) installer to install the skills from this repo:

```sh
npx skills add eai-org/agent-toolkit
```

## Install via Claude Code plugin marketplace

Add the marketplace, then install the toolkit:

```
/plugin marketplace add eai-org/agent-toolkit
/plugin install agent-toolkit
```

All skills install together, namespaced as `/agent-toolkit:<skill>` (for example
`/agent-toolkit:memory-doctor`).

## Install via agentwheel

[agentwheel](https://github.com/NestDevLab/agentwheel) installs the rules and skills together
across Claude, Codex, Copilot, and other runtimes — see
[install-with-agentwheel.md](./install-with-agentwheel.md).
