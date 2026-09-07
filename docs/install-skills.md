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
re-pointed, and broken links owned by this repo are pruned — so `git pull && ./install.sh` brings
an existing install up to date, as long as the entries really are symlinks (see
[Windows](#windows)).

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
./install.sh --no-auto-update        # do not register the daily self-update hook (persists)
./install.sh --auto-update           # register it again after --no-auto-update
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

## Staying up to date

When Claude Code is detected, the install also registers a `SessionStart` hook that fast-forwards
the clone once a day and re-runs the installers, so you do not have to
([auto-update.md](./auto-update.md) covers it in full, other agents included). It is registered
only for Claude's own `~/.claude/skills` (or `~/.claude/rules`), and only for a clone that tracks
an upstream; anything else — another agent, a project's `.claude/skills` — gets the one-liner to
wire by hand instead. `--no-auto-update` turns it off and is remembered, `--auto-update` turns it
back on.

It stays quiet unless the clone is stuck — dirty, detached, without an upstream, off the default
branch, or diverged — and then says so once, naming the fix. Where entries were installed as
copies rather than links ([Windows](#windows)), it says to re-run the installer with `--force`.

## Windows

Git Bash and MSYS silently copy instead of linking when they cannot create a native symlink, which
takes either Windows Developer Mode or an elevated shell and so is not the default situation. A
copy still looks like a working install, but it is a snapshot frozen at install time that
re-running skips (a copy is not a link this repo owns), so the installed content quietly stays on
its original version forever.

The skills escape this: each one is a directory, and `install.sh` falls back to a
[directory junction](https://learn.microsoft.com/en-us/windows/win32/fileio/hard-links-and-junctions),
which needs no privilege and which MSYS reads back as a symlink. A plain `./install.sh` therefore
gives you links that follow the repo, and `git pull && ./install.sh` keeps them current.

If you installed the skills before junctions existed, your entries are still copies, and a plain
re-run skips them because a copy is not a link this repo owns. Convert them once with `--force`,
after which the plain command is enough:

```sh
git pull && ./install.sh --force
```

The rules are single `.md` files, which junctions cannot cover, so
`install-opinionated-rules.sh` still copies them unless you have Developer Mode or an elevated
shell. They need that `--force` on every update, not just once:

```sh
git pull && ./install-opinionated-rules.sh --force
```

Two limits worth knowing about `--force`. It overwrites whatever holds the name, including an entry
you put there yourself by hand. And it refreshes content only, so where entries are copies, one
deleted from this repo stays installed: pruning recognizes broken symlinks, and a copy is not one.
Junction-linked skills are pruned normally.

Each installer checks the entries it created and warns only when they really are copies. Junctions
are a local-NTFS feature, so a destination on a network or non-NTFS drive falls back to copying
even where the rest of the install links, which is worth knowing if you point `--skills-dir` at
another volume.

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
