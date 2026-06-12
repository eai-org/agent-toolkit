# Agent Toolkit Guide

On this repo I keep all my personal rules and skills for Claude Code and other agents, so I can
reuse them across projects and share them with the community.

The general rule here is that everything is self-contained and generic enough to be reusable in any
project, so avoid project-specific logic or assumptions.

When writing or editing Markdown documents, wrap lines at the `max_line_length` set in
`.editorconfig`. This applies to prose; never break code blocks, tables, URLs, or links to satisfy
it.

When changing skills, rules, manifests, install behavior, or repository conventions, keep the
documentation updated in the same change. Update `README.md`, `AGENTS.md`, and any affected
artifact documentation so a fresh agent session can understand the current behavior without prior
conversation context.
