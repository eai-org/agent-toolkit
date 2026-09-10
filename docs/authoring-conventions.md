# Authoring conventions

How to write and edit this repo's artifacts — skills, rules, docs, manifests.

## Framing

Frame rules and skills as agent- and model-agnostic: describe what they do, not tied to a specific
agent (e.g. "for Claude Code") or model. Install instructions may still name agent-specific paths
(e.g. `~/.claude/skills/`) — that's the install mechanism, not the content's framing.

New skills ship at version `0.1` as a trial; bump to `1.0` only after a successful real-world run.
Every other change bumps the last component, unless an uncommitted bump is already pending.

## Multi-agent quirks

Skills with `disable-model-invocation: true` also need `type: flow`, or Kimi Code hides them even
from manual invocation.

Never put a `:` in a skill description — `: ` in the unquoted value breaks strict YAML parsers
(e.g. Copilot's); avoid the character entirely instead of quoting.

## Markdown

Wrap prose lines at the `max_line_length` in `.editorconfig`. Never break code (fenced blocks or
inline backtick spans — a command stays on one line even past the limit), tables, URLs, links, or
YAML frontmatter values to satisfy it.

## Keeping the docs in sync

When changing skills, rules, manifests, install behavior, or repository conventions, update the
docs in the same change — `README.md`, `AGENTS.md`, `docs/`, and any affected artifact
documentation — so a fresh agent session understands the current behavior without prior
conversation context. Keep `README.md` lean: catalogs and quick-install commands only; detailed
guides belong in `docs/`.
