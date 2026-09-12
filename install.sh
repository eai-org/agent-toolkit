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
#   --exclude NAME     Skip this skill and remove our link to it (persists)
#   --include NAME     Install it again after --exclude
#   --no-auto-update   Do not register the daily self-update hook (persists)
#   --auto-update      Register it again after --no-auto-update
#   -h, --help         Show this help
#
# When Claude Code is detected, this also registers a hook that fast-forwards
# this clone once a day and re-runs the installers: docs/auto-update.md.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR_LOGICAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "${REPO_DIR}/lib/install-utils.sh"

AGENTS_DIR="${HOME}/.agents"
SKILLS_DIR="${HOME}/.claude/skills"
FORCE=0
AUTO_UPDATE=""
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
TARGET_FLAG=--skills-dir
EXCLUDE_ADD=()
EXCLUDE_DEL=()

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
  --exclude NAME     Skip this skill and remove our link to it (persists)
  --include NAME     Install it again after --exclude
  --no-auto-update   Do not register the daily self-update hook (persists)
  --auto-update      Register it again after --no-auto-update
  -h, --help         Show this help

Every skill is installed by default. --exclude is repeatable and is
remembered in <agents-dir>/excluded-skills, so the daily self-update honours
it instead of putting the skill back.

When Claude Code is detected, this also registers a hook that fast-forwards
this clone once a day and re-runs the installers: docs/auto-update.md.
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
    --exclude) EXCLUDE_ADD+=("$2"); shift 2 ;;
    --include) EXCLUDE_DEL+=("$2"); shift 2 ;;
    --no-auto-update) AUTO_UPDATE=off; shift ;;
    --auto-update) AUTO_UPDATE=on; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

resolve_agents_dir
load_exclusions excluded-skills
for name in ${EXCLUDE_ADD[@]+"${EXCLUDE_ADD[@]}"}; do
  [ -d "${REPO_DIR}/skills/${name}" ] || echo "Note: no skill named ${name} in this repo; excluding it anyway." >&2
  exclude_add "$name"
done
for name in ${EXCLUDE_DEL[@]+"${EXCLUDE_DEL[@]}"}; do
  exclude_remove "$name"
done
save_exclusions || echo "Warning: could not write ${EXCLUDE_FILE}; the exclusions apply to this run only." >&2

# Phase 1: populate the agent-neutral dir with links into the repo.
# Pruning the agents dir first breaks downstream agent links for removed
# items, so the phase-2 prune can catch them in the same run.
echo "Agents dir -> ${AGENTS_DIR}/skills"
mkdir -p "${AGENTS_DIR}/skills"
prune_dir "${AGENTS_DIR}/skills"
begin_phase
for skill in "${REPO_DIR}"/skills/*/; do
  [ -d "$skill" ] || continue
  if is_excluded "$(basename "${skill%/}")"; then
    unlink_one "$(basename "${skill%/}")" "${AGENTS_DIR}/skills"
    continue
  fi
  link_one "${skill%/}" "${AGENTS_DIR}/skills"
done
end_phase

# Phase 2: populate the agent's dir with links to the agent-neutral entries.
# Skipped entirely when the agent dir IS the agent-neutral dir: linking a dir
# onto itself would turn every entry into a self-referential symlink.
# Entries phase 1 could not provide (e.g. a foreign broken symlink holding the
# name) are skipped too, so no dangling chain links are created.
echo "Skills -> ${SKILLS_DIR}"
mkdir -p "$SKILLS_DIR"
TARGET_DIR="$(cd "$SKILLS_DIR" && pwd -P)"
if [ "$TARGET_DIR" = "${AGENTS_DIR}/skills" ]; then
  echo "  ok     (this is the agents dir itself; already populated)"
else
  # Excluded entries go first: phase 1 removed what they point at, so leaving
  # them to prune_dir would report them as pruned rather than as excluded.
  for skill in "${REPO_DIR}"/skills/*/; do
    [ -d "$skill" ] || continue
    is_excluded "$(basename "${skill%/}")" || continue
    unlink_one "$(basename "${skill%/}")" "$SKILLS_DIR"
  done
  prune_dir "$SKILLS_DIR"
  begin_phase
  for skill in "${REPO_DIR}"/skills/*/; do
    [ -d "$skill" ] || continue
    is_excluded "$(basename "${skill%/}")" && continue
    src="${AGENTS_DIR}/skills/$(basename "${skill%/}")"
    if [ ! -e "$src" ]; then
      count_skip
      echo "  skip   $(basename "${skill%/}") (no usable entry in agents dir)"
      continue
    fi
    link_one "$src" "$SKILLS_DIR"
  done
  end_phase
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

report_install_health
finish_auto_update

echo "Done."
