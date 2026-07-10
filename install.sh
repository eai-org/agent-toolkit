#!/usr/bin/env bash
#
# Symlink every rule and skill from this repo into agent config directories,
# in two layers:
#
#   1. the agent-neutral dir (default: ~/.agents/{rules,skills}) gets one link
#      per rule file / skill directory, pointing into this repo;
#   2. the agent's own dirs (default: ~/.claude/{rules,skills}) get links
#      pointing at the corresponding agent-neutral entries.
#
# Each rule (rules/*.md) and each skill (skills/<name>/) is linked
# individually, so you can also link just the ones you want by hand instead
# of running this.
#
# Re-running converges: correct links are left alone, links owned by this
# repo that point elsewhere (e.g. the old direct layout) are re-pointed, and
# broken links owned by this repo are pruned. To wire up another agent, run
# again with its --rules-dir/--skills-dir.
#
# Usage:
#   ./install.sh [options]
#
# Options:
#   --agents-dir DIR   Agent-neutral directory   (default: ~/.agents)
#   --rules-dir DIR    Agent's rules directory   (default: ~/.claude/rules)
#   --skills-dir DIR   Agent's skills directory  (default: ~/.claude/skills)
#   --rules-only       Link rules only
#   --skills-only      Link skills only
#   --force            Overwrite real files/dirs and foreign symlinks
#   -h, --help         Show this help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AGENTS_DIR="${HOME}/.agents"
RULES_DIR="${HOME}/.claude/rules"
SKILLS_DIR="${HOME}/.claude/skills"
DO_RULES=1
DO_SKILLS=1
FORCE=0

usage() {
  cat <<'EOF'
Symlink every rule and skill from this repo into agent config directories,
in two layers:

  1. the agent-neutral dir (default: ~/.agents/{rules,skills}) gets one link
     per rule file / skill directory, pointing into this repo;
  2. the agent's own dirs (default: ~/.claude/{rules,skills}) get links
     pointing at the corresponding agent-neutral entries.

Each rule (rules/*.md) and each skill (skills/<name>/) is linked
individually, so you can also link just the ones you want by hand instead
of running this.

Re-running converges: correct links are left alone, links owned by this
repo that point elsewhere (e.g. the old direct layout) are re-pointed, and
broken links owned by this repo are pruned. To wire up another agent, run
again with its --rules-dir/--skills-dir.

Usage:
  ./install.sh [options]

Options:
  --agents-dir DIR   Agent-neutral directory   (default: ~/.agents)
  --rules-dir DIR    Agent's rules directory   (default: ~/.claude/rules)
  --skills-dir DIR   Agent's skills directory  (default: ~/.claude/skills)
  --rules-only       Link rules only
  --skills-only      Link skills only
  --force            Overwrite real files/dirs and foreign symlinks
  -h, --help         Show this help
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agents-dir) AGENTS_DIR="$2"; shift 2 ;;
    --rules-dir)  RULES_DIR="$2"; shift 2 ;;
    --skills-dir) SKILLS_DIR="$2"; shift 2 ;;
    --rules-only)  DO_SKILLS=0; shift ;;
    --skills-only) DO_RULES=0; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

# Link targets embed AGENTS_DIR and is_ours compares path prefixes, so it
# must be absolute.
mkdir -p "$AGENTS_DIR"
AGENTS_DIR="$(cd "$AGENTS_DIR" && pwd -P)"

# A symlink is "ours" if it points into this repo clone or the agents dir.
is_ours() {
  local target
  target="$(readlink "$1")" || return 1
  [[ "$target" == "${REPO_DIR}"/* || "$target" == "${AGENTS_DIR}"/* ]]
}

# Remove broken symlinks we own from directory $1. Broken foreign symlinks
# are left alone.
prune_dir() {
  local dir="$1" entry
  [ -d "$dir" ] || return 0
  for entry in "$dir"/*; do
    { [ -L "$entry" ] && [ ! -e "$entry" ]; } || continue
    is_ours "$entry" || continue
    rm "$entry"
    echo "  prune  $(basename "$entry")"
  done
}

# Symlink $1 into directory $2, respecting --force.
link_one() {
  local src="$1" dest_dir="$2"
  local name dest
  name="$(basename "$src")"
  dest="${dest_dir}/${name}"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  ok     ${name}"
    return
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ] && is_ours "$dest"; then
      rm "$dest"
      ln -s "$src" "$dest"
      echo "  relink ${name}"
      return
    fi
    if [ "$FORCE" -eq 1 ]; then
      rm -rf "$dest"
    else
      echo "  skip   ${name} (already exists; use --force to overwrite)"
      return
    fi
  fi

  ln -s "$src" "$dest"
  echo "  link   ${name}"
}

# Phase 1: populate the agent-neutral dir with links into the repo.
# Pruning the agents dir first breaks downstream agent links for removed
# items, so the phase-2 prune can catch them in the same run.
if [ "$DO_RULES" -eq 1 ]; then
  echo "Agents dir -> ${AGENTS_DIR}/rules"
  mkdir -p "${AGENTS_DIR}/rules"
  prune_dir "${AGENTS_DIR}/rules"
  for rule in "${REPO_DIR}"/rules/*.md; do
    [ -e "$rule" ] || continue
    link_one "$rule" "${AGENTS_DIR}/rules"
  done
fi

if [ "$DO_SKILLS" -eq 1 ]; then
  echo "Agents dir -> ${AGENTS_DIR}/skills"
  mkdir -p "${AGENTS_DIR}/skills"
  prune_dir "${AGENTS_DIR}/skills"
  for skill in "${REPO_DIR}"/skills/*/; do
    [ -d "$skill" ] || continue
    link_one "${skill%/}" "${AGENTS_DIR}/skills"
  done
fi

# Phase 2: populate the agent's dirs with links to the agent-neutral entries.
# Skipped entirely when the agent dir IS the agent-neutral dir: linking a dir
# onto itself would turn every entry into a self-referential symlink.
# Entries phase 1 could not provide (e.g. a foreign broken symlink holding the
# name) are skipped too, so no dangling chain links are created.
if [ "$DO_RULES" -eq 1 ]; then
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
fi

if [ "$DO_SKILLS" -eq 1 ]; then
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
fi

echo "Done."
