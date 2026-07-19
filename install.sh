#!/usr/bin/env bash
#
# Symlink every skill from this repo into agent config directories, in two
# layers:
#
#   1. the agent-neutral dir (default: ~/.agents/skills) gets one link per
#      skill directory, pointing into this repo;
#   2. the agent's own skills dir (default: ~/.claude/skills) gets links
#      pointing at the corresponding agent-neutral entries.
#
# Each skill (skills/<name>/) is linked individually, so you can also link
# just the ones you want by hand instead of running this.
#
# Re-running converges: correct links are left alone, links owned by this
# repo that point elsewhere (e.g. the old direct layout) are re-pointed, and
# broken links owned by this repo are pruned. To wire up another agent, run
# again with its --skills-dir.
#
# This script installs skills only. The opinionated rules are a separate
# opt-in: ./install-opinionated-rules.sh.
#
# Usage:
#   ./install.sh [options]
#
# Options:
#   --agents-dir DIR   Agent-neutral directory   (default: ~/.agents)
#   --skills-dir DIR   Agent's skills directory  (default: ~/.claude/skills)
#   --force            Overwrite real files/dirs and foreign symlinks
#   -h, --help         Show this help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "${REPO_DIR}/lib/install-utils.sh"

AGENTS_DIR="${HOME}/.agents"
SKILLS_DIR="${HOME}/.claude/skills"
FORCE=0

usage() {
  cat <<'EOF'
Symlink every skill from this repo into agent config directories, in two
layers:

  1. the agent-neutral dir (default: ~/.agents/skills) gets one link per
     skill directory, pointing into this repo;
  2. the agent's own skills dir (default: ~/.claude/skills) gets links
     pointing at the corresponding agent-neutral entries.

Each skill (skills/<name>/) is linked individually, so you can also link
just the ones you want by hand instead of running this.

Re-running converges: correct links are left alone, links owned by this
repo that point elsewhere (e.g. the old direct layout) are re-pointed, and
broken links owned by this repo are pruned. To wire up another agent, run
again with its --skills-dir.

This script installs skills only. The opinionated rules are a separate
opt-in: ./install-opinionated-rules.sh.

Usage:
  ./install.sh [options]

Options:
  --agents-dir DIR   Agent-neutral directory   (default: ~/.agents)
  --skills-dir DIR   Agent's skills directory  (default: ~/.claude/skills)
  --force            Overwrite real files/dirs and foreign symlinks
  -h, --help         Show this help
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agents-dir) AGENTS_DIR="$2"; shift 2 ;;
    --skills-dir) SKILLS_DIR="$2"; shift 2 ;;
    # Deprecated no-op: this script installs skills only.
    --skills-only) shift ;;
    --rules-only|--rules-dir)
      echo "install.sh installs skills only; for the rules run ./install-opinionated-rules.sh instead." >&2
      exit 1 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

resolve_agents_dir

# Phase 1: populate the agent-neutral dir with links into the repo.
# Pruning the agents dir first breaks downstream agent links for removed
# items, so the phase-2 prune can catch them in the same run.
echo "Agents dir -> ${AGENTS_DIR}/skills"
mkdir -p "${AGENTS_DIR}/skills"
prune_dir "${AGENTS_DIR}/skills"
for skill in "${REPO_DIR}"/skills/*/; do
  [ -d "$skill" ] || continue
  link_one "${skill%/}" "${AGENTS_DIR}/skills"
done

# Phase 2: populate the agent's dir with links to the agent-neutral entries.
# Skipped entirely when the agent dir IS the agent-neutral dir: linking a dir
# onto itself would turn every entry into a self-referential symlink.
# Entries phase 1 could not provide (e.g. a foreign broken symlink holding the
# name) are skipped too, so no dangling chain links are created.
echo "Skills -> ${SKILLS_DIR}"
mkdir -p "$SKILLS_DIR"
if [ "$(cd "$SKILLS_DIR" && pwd -P)" = "${AGENTS_DIR}/skills" ]; then
  echo "  ok     (this is the agents dir itself; already populated)"
else
  prune_dir "$SKILLS_DIR"
  for skill in "${REPO_DIR}"/skills/*/; do
    [ -d "$skill" ] || continue
    src="${AGENTS_DIR}/skills/$(basename "${skill%/}")"
    if [ ! -e "$src" ]; then
      echo "  skip   $(basename "${skill%/}") (no usable entry in agents dir)"
      continue
    fi
    link_one "$src" "$SKILLS_DIR"
  done
fi

# Rule links from earlier installs are managed by the opt-in installer; leave
# them untouched and point the user there. Read-only check on purpose.
if [ -d "${AGENTS_DIR}/rules" ]; then
  for entry in "${AGENTS_DIR}/rules"/*; do
    { [ -L "$entry" ] && is_ours "$entry"; } || continue
    echo "Note: rules from this repo are linked in ${AGENTS_DIR}/rules; run ./install-opinionated-rules.sh to keep them updated."
    break
  done
fi

echo "Done."
