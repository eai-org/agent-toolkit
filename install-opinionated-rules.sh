#!/usr/bin/env bash
#
# Symlink every rule from this repo into agent config directories, in two
# layers:
#
#   1. the agent-neutral dir (default: ~/.agents/rules) gets one link per
#      rule file, pointing into this repo;
#   2. the agent's own rules dir (default: ~/.claude/rules) gets links
#      pointing at the corresponding agent-neutral entries.
#
# The rules are the toolkit's opinionated layer — always-on behavior
# policies. Skills never depend on them; installing rules is a deliberate
# opt-in, which is why this lives apart from ./install.sh (skills).
#
# Each rule (rules/*.md) is linked individually, so you can also link just
# the ones you want by hand instead of running this.
#
# Re-running converges: correct links are left alone, links owned by this
# repo that point elsewhere (e.g. the old direct layout) are re-pointed, and
# broken links owned by this repo are pruned. To wire up another agent, run
# again with its --rules-dir.
#
# Usage:
#   ./install-opinionated-rules.sh [options]
#
# Options:
#   --agents-dir DIR   Agent-neutral directory   (default: ~/.agents)
#   --rules-dir DIR    Agent's rules directory   (default: ~/.claude/rules)
#   --force            Overwrite real files/dirs and foreign symlinks
#   -h, --help         Show this help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "${REPO_DIR}/lib/install-utils.sh"

AGENTS_DIR="${HOME}/.agents"
RULES_DIR="${HOME}/.claude/rules"
FORCE=0

usage() {
  cat <<'EOF'
Symlink every rule from this repo into agent config directories, in two
layers:

  1. the agent-neutral dir (default: ~/.agents/rules) gets one link per
     rule file, pointing into this repo;
  2. the agent's own rules dir (default: ~/.claude/rules) gets links
     pointing at the corresponding agent-neutral entries.

The rules are the toolkit's opinionated layer — always-on behavior
policies. Skills never depend on them; installing rules is a deliberate
opt-in, which is why this lives apart from ./install.sh (skills).

Each rule (rules/*.md) is linked individually, so you can also link just
the ones you want by hand instead of running this.

Re-running converges: correct links are left alone, links owned by this
repo that point elsewhere (e.g. the old direct layout) are re-pointed, and
broken links owned by this repo are pruned. To wire up another agent, run
again with its --rules-dir.

Usage:
  ./install-opinionated-rules.sh [options]

Options:
  --agents-dir DIR   Agent-neutral directory   (default: ~/.agents)
  --rules-dir DIR    Agent's rules directory   (default: ~/.claude/rules)
  --force            Overwrite real files/dirs and foreign symlinks
  -h, --help         Show this help
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agents-dir) AGENTS_DIR="$2"; shift 2 ;;
    --rules-dir)  RULES_DIR="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

resolve_agents_dir

# Phase 1: populate the agent-neutral dir with links into the repo.
# Pruning the agents dir first breaks downstream agent links for removed
# items, so the phase-2 prune can catch them in the same run.
echo "Agents dir -> ${AGENTS_DIR}/rules"
mkdir -p "${AGENTS_DIR}/rules"
prune_dir "${AGENTS_DIR}/rules"
for rule in "${REPO_DIR}"/rules/*.md; do
  [ -e "$rule" ] || continue
  link_one "$rule" "${AGENTS_DIR}/rules"
done

# Phase 2: populate the agent's dir with links to the agent-neutral entries.
# Skipped entirely when the agent dir IS the agent-neutral dir: linking a dir
# onto itself would turn every entry into a self-referential symlink.
# Entries phase 1 could not provide (e.g. a foreign broken symlink holding the
# name) are skipped too, so no dangling chain links are created.
echo "Rules -> ${RULES_DIR}"
mkdir -p "$RULES_DIR"
if [ "$(cd "$RULES_DIR" && pwd -P)" = "${AGENTS_DIR}/rules" ]; then
  echo "  ok     (this is the agents dir itself; already populated)"
else
  prune_dir "$RULES_DIR"
  for rule in "${REPO_DIR}"/rules/*.md; do
    [ -e "$rule" ] || continue
    src="${AGENTS_DIR}/rules/$(basename "$rule")"
    if [ ! -e "$src" ]; then
      echo "  skip   $(basename "$rule") (no usable entry in agents dir)"
      continue
    fi
    link_one "$src" "$RULES_DIR"
  done
fi

echo "Done."
