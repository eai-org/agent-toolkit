# Agent Toolkit Guide

On this repo I keep all my personal rules and skills for Claude Code and other agents, so I can
reuse them across projects and share them with the community.

The general rule here is that everything is self-contained and generic enough to be reusable in any
project, so avoid project-specific logic or assumptions.

Frame rules and skills as agent-agnostic: describe what they do, not as "for Claude Code" or any
specific agent. Install instructions may still reference agent-specific paths (e.g.
`~/.claude/skills/`), since that's the install mechanism, not how the content is framed.

When writing or editing Markdown documents, wrap lines at the `max_line_length` set in
`.editorconfig`. This applies to prose; never break code (fenced blocks or inline backtick
spans — a command must stay on one line even past the limit), tables, URLs, links, or YAML
frontmatter values to satisfy it.

When changing skills, rules, manifests, install behavior, or repository conventions, keep the
documentation updated in the same change. Update `README.md`, `AGENTS.md`, and any affected
artifact documentation so a fresh agent session can understand the current behavior without prior
conversation context.
