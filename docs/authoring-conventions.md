# Authoring conventions

How to write and edit this repo's artifacts — skills, rules, docs, manifests, install scripts.

## Framing

Frame rules and skills as agent- and model-agnostic: describe what they do, not tied to a specific
agent (e.g. "for Claude Code") or model. Install instructions may still name agent-specific paths
(e.g. `~/.claude/skills/`) — that's the install mechanism, not the content's framing.

New skills ship at version `0.1` as a trial; bump to `1.0` only after a successful real-world run.
Every other change bumps the last component, unless an uncommitted bump is already pending or the
branch already raised it against `main`.

## Multi-agent quirks

Skills with `disable-model-invocation: true` also need `type: flow`, or Kimi Code hides them even
from manual invocation.

Never put a `:` in a skill description — `: ` in the unquoted value breaks strict YAML parsers
(e.g. Copilot's); avoid the character entirely instead of quoting.

refine-ticket, refine-pr-review, create-implementation-plan and create-manual-test-instructions
say "Invoke manually only" in the description and carry no `disable-model-invocation` flag on
purpose: sibling skills and `--name` launches must be able to start them. Do not add the flag.

## Next-phase hand-off

A skill that ends by handing work to another skill prints one copy-pasteable launch command per
next phase — the syntax of the agent in use, `claude` only the example, session named
`<phase>-<slug>` — then the alternative of clearing the current session (`/clear`, again only the
example) and running the next skill in it. A line for an optional sibling says "when available".

## Markdown

Wrap prose lines at the `max_line_length` in `.editorconfig`. Never break code (fenced blocks or
inline backtick spans — a command stays on one line even past the limit), tables, URLs, links, or
YAML frontmatter values to satisfy it.

## Checks

Before shipping a skill, run `skills/compact-skill-creator/scripts/check-skill.sh <skill-dir>`
(wrap, links, frontmatter, version at HEAD and merge base); any other doc goes through
`skills/compact-docs-writer/scripts/check-doc.sh <file>`. `test/compact-skill-creator/run.sh` is
their harness: a behaviour change to either script adds or extends a fixture there in the same
change.

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
