# Agent Toolkit Guide

A collection of reusable skills and rules for AI agents (Claude Code and similar). Everything must
be self-contained and generic — reusable in any project — so avoid project-specific logic or
assumptions. Rules are opt-in: a skill must work correctly with no rules installed, so never fix
or extend a skill by adding a rule it depends on.

Test harnesses, for a skill or an install script, live in `test/<name>/` — repo-internal, never
installed; their `runs/` output dirs are gitignored. Planning documents go in `.agents/plans/`
(gitignored).

`workflow-band/` is a Claude Code mod with its tests inside it: run them with `claude plugin test .`
from the repo root, validate with `claude plugin validate .`.

## Docs

- [docs/authoring-conventions.md](docs/authoring-conventions.md) — read before editing any skill,
  rule, doc, manifest or install script.
- [docs/core-philosophy.md](docs/core-philosophy.md) — the five pillars and their litmus test;
  read before creating or redesigning a skill, or when brainstorming toolkit direction.
- [docs/contributor-setup.md](docs/contributor-setup.md) — how this repo is wired for agents; read
  when hooking a new agent up to it.
