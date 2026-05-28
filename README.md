# agent-toolkit

My own toolkit for AI Agentic Coding — a collection of reusable, project-agnostic tools.

## Rules

This is a collection of generic rules I use in all of my projects, I apply them at user level rather than per-project.

Each file in [`rules/`](rules) is a single, self-contained behavioral rule.

### Install for Claude Code

Claude Code auto-loads every `*.md` under `~/.claude/rules/` at the start of each session
([docs](https://code.claude.com/docs/en/memory)).

You can (A) either symlink this repo's `rules/` into that location so changes here apply everywhere automatically:

```sh
# A) No existing ~/.claude/rules — link the whole directory.
#    New rules added to this repo are then picked up automatically.
git clone git@github.com:FrancescoBorzi/agent-toolkit.git && cd agent-toolkit
ln -s "$(pwd)/rules" ~/.claude/rules
```

Or (B) manually pick and choose specific rules to link if you already have some rules in place.

```sh
# B) Link only the rules you want instead (safe if ~/.claude/rules already exists).
git clone git@github.com:FrancescoBorzi/agent-toolkit.git && cd agent-toolkit
mkdir -p ~/.claude/rules
ln -s "$(pwd)/rules/git-read-only-by-default.md" ~/.claude/rules/
ln -s "$(pwd)/rules/no-nonsense-comments.md"     ~/.claude/rules/
ln -s "$(pwd)/rules/self-contained-docs.md"      ~/.claude/rules/
```

Start a new session and run `/context` to confirm the rules are loaded. Rules apply at the
user level (all projects); to scope them to one project, symlink into that repo's `.claude/rules/` instead.

## Skills

Collection of skills I use in multiple projects. Each lives in its own directory under [`skills/`](skills)
with a `SKILL.md` describing the trigger, allowed tools, and steps.

### Install all skills via skills.sh

The fastest way to grab everything is the [skills.sh](https://skills.sh/) installer:

```sh
npx skills add FrancescoBorzi/agent-toolkit
```

### Install a specific skill manually

If you only want one skill, symlink its directory into the target `skills/` folder.

You can (A) install it at user level so it's available in every project:

```sh
# A) User-level — available in every project for this user.
git clone git@github.com:FrancescoBorzi/agent-toolkit.git && cd agent-toolkit
mkdir -p ~/.claude/skills
ln -s "$(pwd)/skills/run-nx-checks" ~/.claude/skills/
```

Or (B) scope it to a single project by symlinking into that repo's `.claude/skills/` instead:

```sh
# B) Project-level — scoped to a single repo.
git clone git@github.com:FrancescoBorzi/agent-toolkit.git && cd agent-toolkit
mkdir -p ~/sources/your-project/.claude/skills
ln -s "$(pwd)/skills/run-nx-checks" ~/sources/your-project/.claude/skills/
```

### run-nx-checks

Runs [Nx](https://nx.dev/) checks (`format`/`lint`/`test`/`build`) against affected projects
and automatically applies unambiguous fixes — lint auto-fixes, missing imports, obvious type errors — asking
before touching anything judgment-laden. Accepts an optional CPU count and project name as arguments. 
See [`skills/run-nx-checks/SKILL.md`](skills/run-nx-checks/SKILL.md).
