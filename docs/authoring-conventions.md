# Authoring conventions

How to write and edit this repo's artifacts — skills, rules, docs, manifests, install scripts.

## Framing

Frame rules and skills as agent- and model-agnostic: describe what they do, not tied to a specific
agent (e.g. "for Claude Code") or model. Install instructions may still name agent-specific paths
(e.g. `~/.claude/skills/`) — that's the install mechanism, not the content's framing.

New skills ship at version `0.1` as a trial; bump to `1.0` only after a successful real-world run.
Every other change bumps the last component, unless an uncommitted bump is already pending or the
branch already raised it against `main`.

`.claude-plugin/plugin.json` and its marketplace entry carry no `version` on purpose: installs then
track the commit SHA, so every push is an update. Ignore the missing-version warning from
`claude plugin validate`.

## Multi-agent quirks

Skills with `disable-model-invocation: true` also need `type: flow`, or Kimi Code hides them even
from manual invocation.

Never put a `:` in a skill description — `: ` in the unquoted value breaks strict YAML parsers
(e.g. Copilot's); avoid the character entirely instead of quoting.

refine-ticket, refine-pr-review, create-implementation-plan and create-manual-test-instructions
say "Invoke manually only" in the description and carry no `disable-model-invocation` flag on
purpose: sibling skills and `--name` launches must be able to start them. Do not add the flag.

## Next-phase hand-off

A skill that ends by handing work to another skill prints each next-phase option as its own fenced
block holding one copy-pasteable launch command — the syntax of the agent in use, `claude` only the
example, session named `<phase>-<slug>` — under a label line saying what the option is and when to
pick it; among alternatives, labels after the first printed start "or" ("Execute the plan:", then
"or split it into tasks first, for small reviewable increments:"), while a further step rather than
an alternative keeps a plain label, and a lone option needs none. Then the alternative: one line
offering to clear the current session (`/clear`, again only the example) and run the next phase
there, followed by the same labelled blocks with the bare prompts, same order. An option naming an
optional sibling is printed only when that skill is available.

## Markdown

Wrap prose lines at the `max_line_length` in `.editorconfig`. Never break code (fenced blocks or
inline backtick spans — a command stays on one line even past the limit), tables, URLs, links, or
YAML frontmatter values to satisfy it.

## Checks

Before shipping a skill, run `skills/compact-skill-creator/scripts/check-skill.sh <skill-dir>`
(wrap, links, frontmatter, version at HEAD and merge base); any other doc goes through
`skills/compact-docs-writer/scripts/check-doc.sh <file>`. The merge-base version is taken against
a base ref resolved offline — `CHECK_SKILL_BASE`, else the remote-HEAD symref of `upstream` then
`origin`, else the sole candidate among main, master, develop, development — and the version line
names the ref it used; `base unknown` means set the override. Both scripts judge a CRLF file as
its LF form. `test/compact-skill-creator/run.sh` is their harness: a behaviour change to either
script adds or extends a fixture there in the same change.

## Install scripts

An option whose value is stored in a file rejects it before storing when it is empty, starts with
`-`, or the file's line format cannot hold it (a newline, a leading `#`).

A behaviour change to `install.sh`, `install-opinionated-rules.sh` or `lib/*.sh` adds or extends a
case in `test/auto-update/run.sh` in the same change.

## Keeping the docs in sync

When changing skills, rules, manifests, install behavior, or repository conventions, update the
docs in the same change — `README.md`, `AGENTS.md`, `docs/`, and any affected artifact
documentation — so a fresh agent session understands the current behavior without prior
conversation context. Keep `README.md` lean: catalogs and quick-install commands only; detailed
guides belong in `docs/`.
