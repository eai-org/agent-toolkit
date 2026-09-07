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

SYMLINKS_REAL=1
COPIED_KIND=dir
NOTHING_INSTALLED=0
PHASE_DONE=0
PHASE_SKIPPED=0
EXISTING_SKIPPED=0

WINDOWS=0
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) WINDOWS=1 ;;
esac

# Link $1 to $2, the best way this environment allows.
#
# Git Bash/MSYS silently copies instead of linking unless the process may create
# native symlinks, which takes Developer Mode or elevation; nativestrict turns
# that silent copy into an error we can fall back from. A directory junction is
# the fallback: it needs no privilege, and MSYS reads one back as a symlink, so
# readlink, -L and rm behave as the rest of this file assumes. Junctions cover
# directories on a local NTFS volume only, hence the plain ln -s last resort,
# which copies.
make_link() {
  local src="$1" dest="$2"
  if [ "$WINDOWS" -eq 1 ]; then
    MSYS=winsymlinks:nativestrict ln -s -- "$src" "$dest" 2>/dev/null && return 0
    if [ -d "$src" ] && command -v cygpath >/dev/null 2>&1; then
      MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
        cmd /c mklink /J "$(cygpath -w "$dest")" "$(cygpath -w "$src")" >/dev/null 2>&1 && return 0
    fi
  fi
  ln -s -- "$src" "$dest"
}

# Record whether the entry make_link just created is a real link. Copies are
# snapshots that never track the repo, and re-running skips them because they
# are not links we own, so an install silently freezes at whatever it was on its
# first run. Judged from the finished entry rather than an up-front probe:
# junctions are a per-volume feature and the two destinations an installer
# writes to can sit on different ones. report_install_health decides whether
# what we saw is worth telling the user.
note_link_kind() {
  local dest="$1"
  [ -L "$dest" ] && return 0
  SYMLINKS_REAL=0
  if [ -d "$dest" ]; then
    COPIED_KIND=dir
  else
    COPIED_KIND=file
  fi
}

# A symlink is "ours" if it points into this repo clone or the agents dir.
# The logical clone path counts too: an install run through a symlinked path
# left links pointing that way, and they must be re-pointed, not skipped as
# someone else's.
is_ours() {
  local target
  target="$(readlink "$1")" || return 1
  [[ "$target" == "${REPO_DIR}"/* \
    || "$target" == "${REPO_DIR_LOGICAL:-$REPO_DIR}"/* \
    || "$target" == "${AGENTS_DIR}"/* ]]
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
    PHASE_DONE=$((PHASE_DONE + 1))
    return
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ] && is_ours "$dest"; then
      rm -- "$dest"
      make_link "$src" "$dest"
      note_link_kind "$dest"
      echo "  relink ${name}"
      PHASE_DONE=$((PHASE_DONE + 1))
      return
    fi
    if [ "$FORCE" -eq 1 ]; then
      rm -rf -- "$dest"
    else
      echo "  skip   ${name} (already exists; use --force to overwrite)"
      count_skip
      # Counted apart from count_skip and across phases: record_invocation needs
      # to know a foreign entry was left alone anywhere in the run.
      EXISTING_SKIPPED=$((EXISTING_SKIPPED + 1))
      return
    fi
  fi

  make_link "$src" "$dest"
  note_link_kind "$dest"
  echo "  link   ${name}"
  PHASE_DONE=$((PHASE_DONE + 1))
}

# An entry the caller gave up on before link_one saw it.
count_skip() {
  PHASE_SKIPPED=$((PHASE_SKIPPED + 1))
}

# Phases are counted separately: a phase that installed nothing is worth
# reporting even when the other one did work, since the install as a whole is
# then wired to something this repo did not put there.
begin_phase() {
  PHASE_DONE=0
  PHASE_SKIPPED=0
}

end_phase() {
  if [ "$PHASE_SKIPPED" -gt 0 ] && [ "$PHASE_DONE" -eq 0 ]; then
    NOTHING_INSTALLED=1
  fi
  return 0
}

# Silent unless the run needs something from the user. Two cases qualify: an
# environment that cannot link, where the install looks fine but will never
# update itself, and a phase that installed nothing at all, which otherwise
# reads as a successful no-op. A run that got its work done stays quiet.
report_install_health() {
  if [ "$SYMLINKS_REAL" -eq 0 ]; then
    echo "Warning: this environment copies instead of linking, so the installed entries are" >&2
    echo "  snapshots that do not follow this repo; re-run with --force after updating it to" >&2
    echo "  refresh them." >&2
    # Naming the cause the caller's own entries hit: telling someone whose
    # junctions just failed that junctions cover them sends them after the
    # wrong problem.
    if [ "$COPIED_KIND" = file ]; then
      echo "  On Windows, links to single files like these need Developer Mode or an elevated" >&2
      echo "  shell; junctions, which need neither, cover only directories." >&2
    else
      echo "  On Windows these normally fall back to junctions, which need a local NTFS volume," >&2
      echo "  so a network or non-NTFS destination is the usual cause." >&2
    fi
  elif [ "$NOTHING_INSTALLED" -eq 1 ]; then
    echo "The install names are held by entries this script does not own, so the installed" >&2
    echo "  content will not follow this repo. Re-run with --force to replace those entries" >&2
    echo "  (this deletes what is currently there)." >&2
  fi
}

# ---------------------------------------------------------------------------
# Auto-update wiring
#
# Callers that want it also set SCRIPT_NAME, TARGET_FLAG, TARGET_DIR and
# AUTO_UPDATE, then call finish_auto_update at the end of a run.
# ---------------------------------------------------------------------------

AUTO_UPDATE_MARK="/lib/auto-update.sh"

# Where this clone keeps its update state. Inside the git dir so a second clone
# tracks its own, and nothing lands in the working tree. --absolute-git-dir
# because hooks run from the session's project dir, and it also resolves the
# real dir for linked worktrees and submodules.
toolkit_state_dir() {
  local git_dir
  git_dir="$(git -C "$REPO_DIR" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  [ -n "$git_dir" ] || return 1
  mkdir -p "${git_dir}/agent-toolkit" 2>/dev/null || return 1
  echo "${git_dir}/agent-toolkit"
}

# One tab-separated line per install, keyed by script + target dir, for the
# update script to replay:
#   script  agents_dir  target_flag  target_dir  head  copies
record_invocation() {
  local state="$1"
  local file="${state}/invocations" tmp="${state}/invocations.$$"
  local head prev copies

  head="$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)" || head=""

  prev=""
  if [ -f "$file" ]; then
    prev="$(awk -F '\t' -v s="$SCRIPT_NAME" -v t="$TARGET_DIR" \
      '$1 == s && $4 == t { c = $6 } END { print c }' "$file" 2>/dev/null)" || prev=""
  fi
  [ -n "$prev" ] || prev=0

  # Sticky on purpose: a re-run leaves an existing copy alone as a foreign
  # entry, so SYMLINKS_REAL stays 1 and would clear a flag that still holds.
  if [ "$SYMLINKS_REAL" -eq 0 ]; then
    copies=1
  elif [ "$EXISTING_SKIPPED" -eq 0 ]; then
    copies=0
  else
    copies="$prev"
  fi

  : >"$tmp" || return 1
  if [ -f "$file" ]; then
    awk -F '\t' -v s="$SCRIPT_NAME" -v t="$TARGET_DIR" \
      '!($1 == s && $4 == t)' "$file" >>"$tmp" 2>/dev/null || true
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$SCRIPT_NAME" "$AGENTS_DIR" "$TARGET_FLAG" "$TARGET_DIR" "$head" "$copies" >>"$tmp"
  mv -f "$tmp" "$file"
}

# Converge our SessionStart handler in a settings file, leaving everything else
# alone. Whichever of python3, node or jq works first does the edit; the file
# is rewritten (atomically, since agents watch it) only when the parsed
# structure really changed.
#
# Returns: 0 written, 2 already as we want it, 3 file we cannot parse,
# 4 no usable interpreter.
settings_merge() {
  local file="$1" mode="$2" cmd="$3"
  local tmp="${file}.tmp.$$" rc=4

  # Probe each interpreter before trusting its exit code: the Windows Store
  # python3 stub exits non-zero without running anything.
  if python3 -c 'import json' >/dev/null 2>&1; then
    settings_merge_python "$file" "$mode" "$cmd" "$tmp"
    rc=$?
  fi
  if [ "$rc" -eq 4 ] && node -e '' >/dev/null 2>&1; then
    settings_merge_node "$file" "$mode" "$cmd" "$tmp"
    rc=$?
  fi
  if [ "$rc" -eq 4 ] && printf '{}' | jq . >/dev/null 2>&1; then
    settings_merge_jq "$file" "$mode" "$cmd" "$tmp"
    rc=$?
  fi

  if [ "$rc" -eq 0 ]; then
    if [ -s "$tmp" ]; then
      mv -f "$tmp" "$file"
    else
      rc=4
    fi
  fi
  rm -f "$tmp" 2>/dev/null || true
  return "$rc"
}

settings_merge_python() {
  local rc
  python3 - "$1" "$2" "$3" "$4" "$AUTO_UPDATE_MARK" <<'PY'
import copy, json, sys

path, mode, cmd, tmp, mark = sys.argv[1:6]
entry = {"type": "command", "command": cmd, "timeout": 10}

try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except FileNotFoundError:
    if mode == "remove":
        sys.exit(2)
    data = {}
except Exception:
    sys.exit(3)

if not isinstance(data, dict):
    sys.exit(3)

hooks = data.get("hooks")
if hooks is None:
    if mode == "remove":
        sys.exit(2)
    hooks = {}
elif not isinstance(hooks, dict):
    sys.exit(3)

groups = hooks.get("SessionStart")
if groups is None:
    if mode == "remove":
        sys.exit(2)
    groups = []
elif not isinstance(groups, list):
    sys.exit(3)
for group in groups:
    if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
        sys.exit(3)

before = copy.deepcopy(data)


def ours(handler):
    return (isinstance(handler, dict)
            and isinstance(handler.get("command"), str)
            and mark in handler["command"])


kept_one = False
new_groups = []
for group in groups:
    had = any(ours(h) for h in group["hooks"])
    kept = []
    for handler in group["hooks"]:
        if ours(handler):
            if mode == "register" and not kept_one:
                kept_one = True
                kept.append(dict(entry))
            continue
        kept.append(handler)
    group["hooks"] = kept
    # A group we emptied is ours to clean up; one that came in empty is the
    # user's business.
    if had and not kept:
        continue
    new_groups.append(group)

if mode == "register":
    if not kept_one:
        new_groups.append({"matcher": "startup", "hooks": [dict(entry)]})
    hooks["SessionStart"] = new_groups
    data["hooks"] = hooks
elif new_groups:
    hooks["SessionStart"] = new_groups
else:
    hooks.pop("SessionStart", None)

if data == before:
    sys.exit(2)

with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
  rc=$?
  case "$rc" in 0|2|3) return "$rc" ;; *) return 4 ;; esac
}

settings_merge_node() {
  local rc
  node - "$1" "$2" "$3" "$4" "$AUTO_UPDATE_MARK" <<'JS'
const fs = require("fs");
const [path, mode, cmd, tmp, mark] = process.argv.slice(2);
const entry = () => ({ type: "command", command: cmd, timeout: 10 });

let raw = null;
try {
  raw = fs.readFileSync(path, "utf8");
} catch (err) {
  if (err.code !== "ENOENT") process.exit(3);
  if (mode === "remove") process.exit(2);
}

let data = {};
if (raw !== null) {
  try {
    data = JSON.parse(raw);
  } catch (err) {
    process.exit(3);
  }
}

const isObject = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
if (!isObject(data)) process.exit(3);

let hooks = data.hooks;
if (hooks === undefined) {
  if (mode === "remove") process.exit(2);
  hooks = {};
} else if (!isObject(hooks)) {
  process.exit(3);
}

let groups = hooks.SessionStart;
if (groups === undefined) {
  if (mode === "remove") process.exit(2);
  groups = [];
} else if (!Array.isArray(groups)) {
  process.exit(3);
}
for (const group of groups) {
  if (!isObject(group) || !Array.isArray(group.hooks)) process.exit(3);
}

const before = JSON.stringify(data);
const ours = (h) => isObject(h) && typeof h.command === "string" && h.command.includes(mark);

let keptOne = false;
const newGroups = [];
for (const group of groups) {
  const had = group.hooks.some(ours);
  const kept = [];
  for (const handler of group.hooks) {
    if (ours(handler)) {
      if (mode === "register" && !keptOne) {
        keptOne = true;
        kept.push(entry());
      }
      continue;
    }
    kept.push(handler);
  }
  group.hooks = kept;
  // A group we emptied is ours to clean up; one that came in empty is the
  // user's business.
  if (had && kept.length === 0) continue;
  newGroups.push(group);
}

if (mode === "register") {
  if (!keptOne) newGroups.push({ matcher: "startup", hooks: [entry()] });
  hooks.SessionStart = newGroups;
  data.hooks = hooks;
} else if (newGroups.length > 0) {
  hooks.SessionStart = newGroups;
} else {
  delete hooks.SessionStart;
}

if (JSON.stringify(data) === before) process.exit(2);
fs.writeFileSync(tmp, JSON.stringify(data, null, 2) + "\n");
JS
  rc=$?
  case "$rc" in 0|2|3) return "$rc" ;; *) return 4 ;; esac
}

settings_merge_jq() {
  local file="$1" mode="$2" cmd="$3" tmp="$4"
  local rc

  if [ ! -f "$file" ]; then
    [ "$mode" = remove ] && return 2
  fi

  settings_read_or_empty "$file" | jq -e '
    if type != "object" then false
    elif (has("hooks") | not) then true
    elif (.hooks | type) != "object" then false
    elif (.hooks | has("SessionStart") | not) then true
    elif (.hooks.SessionStart | type) != "array" then false
    else ([ .hooks.SessionStart[]
            | select((type != "object") or ((.hooks | type) != "array")) ] | length) == 0
    end' >/dev/null 2>&1 || return 3

  settings_read_or_empty "$file" \
    | jq --indent 2 --arg cmd "$cmd" --arg mode "$mode" --arg mark "$AUTO_UPDATE_MARK" '
        def ours: (type == "object")
          and ((.command | type) == "string")
          and ((.command | index($mark)) != null);
        def entry: {type: "command", command: $cmd, timeout: 10};

        . as $in
        | ((.hooks.SessionStart // []) | to_entries
           | map(select(.value.hooks | map(ours) | any)) | first | .key?) as $gi
        | (if $gi == null then null
           else (.hooks.SessionStart[$gi].hooks | to_entries
                 | map(select(.value | ours)) | first | .key?) end) as $hi
        | ([ (.hooks.SessionStart // []) | to_entries[]
             | .key as $i | .value as $g
             | ($g.hooks | map(ours) | any) as $had
             | ($g | .hooks = [ $g.hooks[] | select(ours | not) ]) as $clean
             # A group we emptied is ours to clean up; one that came in empty
             # is not ours to touch.
             | if $mode == "register" and $i == $gi
               then [ $clean | .hooks = (.hooks[0:$hi] + [entry] + .hooks[$hi:]) ]
               elif $had and (($clean.hooks | length) == 0) then []
               else [ $clean ] end ]
           | add // []) as $new
        | (if $mode == "remove"
           then (if ($in | has("hooks") | not) or ($in.hooks | has("SessionStart") | not)
                 then $in
                 elif ($new | length) > 0 then ($in | .hooks.SessionStart = $new)
                 else ($in | del(.hooks.SessionStart)) end)
           else (if $gi == null
                 then ($new + [{matcher: "startup", hooks: [entry]}])
                 else $new end) as $groups
                | ($in | .hooks = ((.hooks // {}) | .SessionStart = $groups))
           end)
        | if . == $in then empty else . end' >"$tmp" 2>/dev/null
  rc=$?

  [ "$rc" -eq 0 ] || return 4
  [ -s "$tmp" ] || return 2
  return 0
}

settings_read_or_empty() {
  if [ -f "$1" ]; then
    cat "$1"
  else
    printf '{}'
  fi
}

# What to paste when we cannot edit the settings file ourselves.
auto_update_snippet() {
  local file="$1" cmd="$2"
  echo "  Add this to hooks.SessionStart in ${file}:"
  echo "    {"
  echo "      \"matcher\": \"startup\","
  echo "      \"hooks\": [{ \"type\": \"command\", \"command\": \"${cmd}\", \"timeout\": 10 }]"
  echo "    }"
  echo "  Details: docs/auto-update.md"
}

# TARGET_DIR is the agent's own dir, not another agent's and not a project one.
is_claude_target() {
  local cfg="$1" kind dir
  case "$SCRIPT_NAME" in
    install.sh) kind=skills ;;
    *) kind=rules ;;
  esac
  [ -d "${cfg}/${kind}" ] || return 1
  dir="$(cd "${cfg}/${kind}" && pwd -P)" || return 1
  [ "$dir" = "$TARGET_DIR" ]
}

claude_code_detected() {
  local cfg="$1"
  command -v claude >/dev/null 2>&1 && return 0
  [ -f "${cfg}/settings.json" ] && return 0
  [ -f "${HOME}/.claude.json" ] && return 0
  return 1
}

# Record this run and, when it makes sense, wire the daily update hook.
# Always exits 0: an installer that cannot set this up still installed.
finish_auto_update() {
  local state cfg file cmd rc had_ours
  local opt_out

  state="$(toolkit_state_dir)" || {
    echo "Auto-update: off. ${REPO_DIR} is not a git work tree we can read, so it cannot update itself."
    return 0
  }
  record_invocation "$state" || true

  case "${AUTO_UPDATE:-}" in
    off) : >"${state}/opt-out" ;;
    on)  rm -f "${state}/opt-out" ;;
  esac

  cfg="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
  file="${cfg}/settings.json"
  cmd="bash '${REPO_DIR}/lib/auto-update.sh' --json"
  opt_out=0
  [ -e "${state}/opt-out" ] && opt_out=1

  if [ "$opt_out" -eq 1 ]; then
    if [ -f "$file" ] && is_claude_target "$cfg"; then
      rc=0
      settings_merge "$file" remove "$cmd" || rc=$?
      case "$rc" in
        0) echo "Auto-update: off (opted out); removed our hook from ${file}. --auto-update turns it back on." ;;
        3) echo "Auto-update: off (opted out), but ${file} is not valid JSON. Delete the hooks.SessionStart handler whose command contains ${AUTO_UPDATE_MARK} by hand." ;;
        4) echo "Auto-update: off (opted out), but no working python3, node or jq to edit ${file}. Delete the hooks.SessionStart handler whose command contains ${AUTO_UPDATE_MARK} by hand." ;;
        *) echo "Auto-update: off (opted out); no hook of ours in ${file}. --auto-update turns it back on." ;;
      esac
    else
      echo "Auto-update: off (opted out). --auto-update turns it back on."
    fi
    return 0
  fi

  if ! claude_code_detected "$cfg"; then
    echo "Auto-update: nothing registered, no Claude Code found here. docs/auto-update.md covers the other agents."
    return 0
  fi

  if ! is_claude_target "$cfg"; then
    echo "Auto-update: nothing registered for ${TARGET_DIR}, which is not Claude Code's own dir. To wire it up, add a SessionStart hook running: ${cmd}"
    echo "  Details: docs/auto-update.md"
    return 0
  fi

  if ! git -C "$REPO_DIR" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    echo "Auto-update: nothing registered, the branch checked out in ${REPO_DIR} has no upstream to update from. Set one with git -C '${REPO_DIR}' branch --set-upstream-to origin/main, then re-run this script."
    return 0
  fi

  case "$REPO_DIR" in
    *\'*)
      echo "Auto-update: nothing registered, ${REPO_DIR} contains an apostrophe and we cannot quote it in a hook command. Add it by hand, escaping the path yourself:"
      auto_update_snippet "$file" "$cmd"
      return 0 ;;
  esac

  had_ours=0
  if [ -f "$file" ] && grep -q "$AUTO_UPDATE_MARK" "$file" 2>/dev/null; then
    had_ours=1
  fi

  rc=0
  settings_merge "$file" register "$cmd" || rc=$?
  case "$rc" in
    0) if [ "$had_ours" -eq 1 ]; then
         echo "Auto-update: on. Updated our daily SessionStart hook in ${file}."
       else
         echo "Auto-update: on. Registered a daily SessionStart hook in ${file}. --no-auto-update turns it off."
       fi ;;
    2) echo "Auto-update: on. Already registered in ${file}." ;;
    3) echo "Auto-update: nothing registered, ${file} is not valid JSON."
       auto_update_snippet "$file" "$cmd" ;;
    *) echo "Auto-update: nothing registered, no working python3, node or jq to edit ${file}."
       auto_update_snippet "$file" "$cmd" ;;
  esac
  return 0
}
