# Agent Toolkit Guide

A collection of reusable skills and rules for AI agents (Claude Code and similar). Everything must
be self-contained and generic — reusable in any project — so avoid project-specific logic or
assumptions.

Frame rules and skills as agent- and model-agnostic: describe what they do, not tied to a specific
agent (e.g. "for Claude Code") or model. Install instructions may still name agent-specific paths
(e.g. `~/.claude/skills/`) — that's the install mechanism, not the content's framing.

In Markdown, wrap prose lines at the `max_line_length` in `.editorconfig`. Never break code (fenced
blocks or inline backtick spans — a command stays on one line even past the limit), tables, URLs,
links, or YAML frontmatter values to satisfy it.

When changing skills, rules, manifests, install behavior, or repository conventions, update the docs
in the same change — `README.md`, `AGENTS.md`, and any affected artifact documentation — so a fresh
agent session understands the current behavior without prior conversation context.
