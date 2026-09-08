# Auto-update

Once installed, the clone keeps itself current. A daily `SessionStart` hook runs
[`lib/auto-update.sh`](../lib/auto-update.sh), which fetches, fast-forwards the clone, and replays
the installer runs it recorded, so the installed skills and rules follow the repo. Both installers
register the hook when they detect Claude Code; `--no-auto-update` turns it off for good,
`--auto-update` turns it back on.

State lives in `<clone>/.git/agent-toolkit/` — the real git dir, so a linked worktree or a
submodule gets its own: what to replay, when the next run is due, the last run's log, and the last
thing it said.

## What it does, and does not do

- Fast-forward only. A clone that is dirty, detached, without an upstream, off the default branch,
  or diverged is left alone, with one line saying so and naming the fix.
- At most one run a day, and silent whatever the outcome: the only thing it prints is a problem
  you have to fix, once per problem. A failed fetch retries in an hour instead, so a laptop that
  was offline this morning still updates later in the day. Git and installer output goes to the
  log.
- Never `--force`, so an entry the installers do not own is never replaced.
- It does replay the installers, so an update can add skills and rules, or drop ones the repo
  removed. Rules are always-on, so that changes how your agent behaves.

That last point is what to weigh against
[pillar 3](./core-philosophy.md#pillar-3-human-in-the-loop). It stays on by default because the
installer announces it, one flag opts out, and it never puts anything in the model's context: what
it changes is the content of skills and rules you already opted into, exactly what
`git pull && ./install.sh` does by hand.

## Moving or deleting the clone

Run the installer you use with `--no-auto-update` before deleting the clone. If it is already
gone, delete the `hooks.SessionStart` handler whose command contains `/lib/auto-update.sh` from
`~/.claude/settings.json` by hand, or Claude Code reports a failing hook at every startup. A clone
that moved is fixed by re-running the installers from the new place with `--force`, since without
it they skip the links still pointing at the old path as entries they do not own.

## Notes

- With `CLAUDE_CONFIG_DIR` set, pass `--skills-dir "$CLAUDE_CONFIG_DIR/skills"` and `--rules-dir
  "$CLAUDE_CONFIG_DIR/rules"` to get wired up; the hook is registered for Claude's own directories
  only.
- Hooks from user settings do not run in a folder until its workspace-trust dialog is accepted.
- Windows Git Bash: a profile that echoes unconditionally prepends its output to the hook's, so the
  output no longer starts with `{`, and all of it is injected into the model's context. Keep
  profile echoes behind an interactive check.
- Installing through the Claude Code plugin marketplace is a different mechanism with its own
  updates: third-party marketplaces have auto-update **off** by default, switch it on under
  `/plugin` → Marketplaces → Enable auto-update.

## Other agents

The installers only know Claude Code. The recipes below were verified against each agent's docs on
2026-09-06; `<clone>` is this clone's absolute path. The ones that log to a file resolve it through
`git rev-parse`, since in a linked worktree or a submodule `.git` is a file and nothing can be
written beneath it.

### Gemini CLI

In `~/.gemini/settings.json` (`$GEMINI_CLI_HOME` when set), add to `hooks.SessionStart`:

```json
{ "matcher": "startup", "hooks": [{ "type": "command", "command": "bash '<clone>/lib/auto-update.sh' --json", "timeout": 10000 }] }
```

`timeout` is in **milliseconds** here, and `name` is optional. The hook is synchronous but never
blocks startup on its output, stdout must be one JSON object, and `systemMessage` is shown to the
user — so `--json` serves it unchanged.

### Copilot CLI

`~/.copilot/hooks/agent-toolkit.json` (`$COPILOT_HOME/hooks/` when set):

```json
{ "version": 1, "hooks": { "sessionStart": [{ "type": "command", "bash": "bash '<clone>/lib/auto-update.sh' >> \"$(git -C '<clone>' rev-parse --absolute-git-dir)/agent-toolkit/messages.log\"", "timeoutSec": 10 }] } }
```

Stdout is parsed as hook JSON, non-JSON is discarded, and nothing reaches you on exit 0 — hence
plain mode and the redirect, with the stuck and error lines landing in that file. (`powershell` is
the optional sibling of `bash`; `command` is the cross-platform fallback.) Whether the CLI waits
for the hook is undocumented.

### Cursor

`~/.cursor/hooks.json`, for the desktop app (CLI support is undocumented):

```json
{ "version": 1, "hooks": { "sessionStart": [{ "command": "bash '<clone>/lib/auto-update.sh' >> \"$(git -C '<clone>' rev-parse --absolute-git-dir)/agent-toolkit/messages.log\"", "timeout": 10 }] } }
```

It runs from `~/.cursor/`, fire-and-forget, and handles JSON stdout (plain text is undocumented),
hence the redirect again. Cursor can also load Claude Code hooks once third-party configs are
enabled in its settings (Rules, Skills, Subagents → include third-party configs) and the feature
is on for your account; the Claude entry then fires there too, and the lock and the daily stamp
absorb the double run.

### OpenCode

No shell-command hook. Plugins (`~/.config/opencode/plugins/*.js`, or `OPENCODE_CONFIG_DIR`)
receive a `session.created` event and a `$` shell API, but that event has no documented example and
no documented output handling — use the fallback below.

### No hook at all

A cron entry:

```sh
@daily bash '<clone>/lib/auto-update.sh' >> "$(git -C '<clone>' rev-parse --absolute-git-dir)/agent-toolkit/messages.log" 2>/dev/null
```

or a launchd agent with `StartInterval` 86400 running the same command.
