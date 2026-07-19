# Helpers shared by ./install.sh and ./install-opinionated-rules.sh.
#
# Sourced, not run. Callers set REPO_DIR, AGENTS_DIR, and FORCE before using
# the functions below.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "This file provides helpers sourced by the installers; run ./install.sh or ./install-opinionated-rules.sh instead." >&2
  exit 1
fi

# Link targets embed AGENTS_DIR and is_ours compares path prefixes, so it
# must be absolute.
resolve_agents_dir() {
  mkdir -p "$AGENTS_DIR"
  AGENTS_DIR="$(cd "$AGENTS_DIR" && pwd -P)"
}

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
