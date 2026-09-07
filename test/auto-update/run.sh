#!/usr/bin/env bash
#
# Harness for lib/auto-update.sh and the auto-update wiring in the installers.
#
# Usage:
#   bash test/auto-update/run.sh [case ...]
#
# Every case builds its own remote, clone and HOME under
# test/auto-update/runs/<timestamp>/<case>/ and leaves them there to inspect.
# Exits non-zero if any case failed.

set -u

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${HARNESS_DIR}/../.." && pwd -P)"
RUNS="${HARNESS_DIR}/runs/$(date +%Y%m%d-%H%M%S)"
TEMPLATE="${RUNS}/_remote.git"

# /usr/bin holds real git, python3 and jq on macOS, so "no git" and "no
# interpreter" are staged with failing shims in the case's own bin dir; the
# installers test what works, not what exists.
BASE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
REAL_NODE="$(command -v node 2>/dev/null || true)"

# Belt and braces: without a ceiling, a git command in a directory that failed
# to become a repo walks up and hits the developer's own checkout.
export GIT_CEILING_DIRECTORIES="$RUNS"
export GIT_AUTHOR_NAME="Toolkit Harness"
export GIT_AUTHOR_EMAIL="harness@example.invalid"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
unset CLAUDE_CONFIG_DIR
unset GIT_SSH_COMMAND
unset GIT_SSH

die() {
  echo "harness: $*" >&2
  exit 2
}

is_repo_root() {
  [ "$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" = "$1" ]
}

CASE=""
CASE_ROOT=""
CLONE=""
STATE=""
PUSHER=""
OUT=""
CASE_FAILS=0
TOTAL_FAILS=0
RAN=0

# --- assertions ------------------------------------------------------------

fail() {
  echo "    FAIL: $*"
  CASE_FAILS=$((CASE_FAILS + 1))
}

assert_eq() {
  [ "$2" = "$3" ] && return 0
  fail "$1: expected [$2], got [$3]"
}

assert_contains() {
  case "$2" in *"$3"*) return 0 ;; esac
  fail "$1: [$2] does not contain [$3]"
}

assert_not_contains() {
  case "$2" in *"$3"*) fail "$1: [$2] should not contain [$3]" ;; esac
  return 0
}

assert_stdout_is() {
  assert_eq "stdout" "$1" "$2"
}

assert_message_contains() {
  local msg
  msg="$(json_message "$1")"
  assert_contains "message" "$msg" "$2"
}

assert_link() {
  [ -L "$1" ] || fail "expected a symlink at $1"
}

assert_link_target() {
  local got
  got="$(readlink "$1" 2>/dev/null)"
  assert_eq "link target of $1" "$2" "$got"
}

assert_file_missing() {
  if [ -e "$1" ]; then fail "expected $1 to be gone"; fi
}

# --- helpers ---------------------------------------------------------------

json_message() {
  printf '%s' "$1" | /usr/bin/python3 -c \
    'import json,sys; print(json.load(sys.stdin).get("systemMessage",""))' 2>/dev/null
}

settings_file() {
  printf '%s' "${HOME}/.claude/settings.json"
}

# Number of handlers of ours anywhere in hooks.SessionStart.
hook_count() {
  local file
  file="$(settings_file)"
  [ -f "$file" ] || { echo 0; return 0; }
  /usr/bin/python3 - "$file" <<'PY' 2>/dev/null
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    print(-1)
    sys.exit(0)
groups = data.get("hooks", {}).get("SessionStart", [])
print(sum(1 for g in groups for h in g.get("hooks", [])
          if "/lib/auto-update.sh" in (h.get("command") or "")))
PY
}

# Read one value out of the settings file, e.g. hooks.SessionStart.0.matcher.
settings_get() {
  /usr/bin/python3 - "$(settings_file)" "$1" <<'PY' 2>/dev/null
import json, sys
node = json.load(open(sys.argv[1]))
for part in sys.argv[2].split("."):
    node = node[int(part)] if isinstance(node, list) else node[part]
print(node if not isinstance(node, (dict, list)) else json.dumps(node))
PY
}

group_count() {
  /usr/bin/python3 - "$(settings_file)" <<'PYX' 2>/dev/null
import json, sys
print(len(json.load(open(sys.argv[1])).get("hooks", {}).get("SessionStart", [])))
PYX
}

top_level_keys() {
  /usr/bin/python3 - "$(settings_file)" <<'PYX' 2>/dev/null
import json, sys
print(json.dumps(sorted(json.load(open(sys.argv[1])).keys())))
PYX
}

mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

mode() {
  stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1" 2>/dev/null
}

new_case() {
  CASE="$1"
  CASE_FAILS=0
  CASE_ROOT="${RUNS}/${CASE}"
  PUSHER=""
  mkdir -p "${CASE_ROOT}/home" "${CASE_ROOT}/bin"
  cp -R "$TEMPLATE" "${CASE_ROOT}/remote.git"
  export HOME="${CASE_ROOT}/home"
  export PATH="${CASE_ROOT}/bin:${BASE_PATH}"
  git clone -q "${CASE_ROOT}/remote.git" "${CASE_ROOT}/clone" \
    || die "could not clone the case repo for ${CASE}"
  CLONE="${CASE_ROOT}/clone"
  STATE="${CLONE}/.git/agent-toolkit"
  echo "  ${CASE}"
}

# Claude Code is "detected" through this file; the harness PATH has no claude.
detect_claude() {
  : >"${HOME}/.claude.json"
}

ensure_pusher() {
  [ -n "$PUSHER" ] && return 0
  PUSHER="${CASE_ROOT}/pusher"
  git clone -q "${CASE_ROOT}/remote.git" "$PUSHER" || die "could not clone the pusher"
  is_repo_root "$PUSHER" || die "the pusher is not a repo of its own"
}

push_skill() {
  ensure_pusher
  mkdir -p "${PUSHER}/skills/$1"
  printf -- '---\nname: %s\ndescription: harness fixture\n---\n\nFixture.\n' "$1" \
    >"${PUSHER}/skills/$1/SKILL.md"
  git -C "$PUSHER" add -A
  git -C "$PUSHER" commit -qm "add skill $1"
  git -C "$PUSHER" push -q origin main
}

push_file() {
  ensure_pusher
  printf '%s\n' "$2" >"${PUSHER}/$1"
  git -C "$PUSHER" add -A
  git -C "$PUSHER" commit -qm "add $1"
  git -C "$PUSHER" push -q origin main
}

install_skills() {
  OUT="$(bash "${CLONE}/install.sh" "$@" 2>&1)"
  INSTALL_RC=$?
  printf '%s\n' "$OUT" >>"${CASE_ROOT}/install.log"
  return $INSTALL_RC
}

install_rules() {
  OUT="$(bash "${CLONE}/install-opinionated-rules.sh" "$@" 2>&1)"
  INSTALL_RC=$?
  printf '%s\n' "$OUT" >>"${CASE_ROOT}/install.log"
  return $INSTALL_RC
}

run_hook() {
  bash "${CLONE}/lib/auto-update.sh" --json
}

run_hook_plain() {
  bash "${CLONE}/lib/auto-update.sh"
}

make_due() {
  rm -f "${STATE}/stamp"
}

log_text() {
  cat "${STATE}/log" 2>/dev/null
}

record_line() {
  awk -F '\t' -v s="$1" -v t="$2" '$1 == s && $4 == t { line = $0 } END { print line }' \
    "${STATE}/invocations" 2>/dev/null
}

record_field() {
  record_line "$1" "$2" | awk -F '\t' -v n="$3" '{ print $n }'
}

# Every shim goes through here. A plain > follows a symlink, and the node leg of
# case_interpreter_fallthrough puts a link to the developer's own node in bin/ --
# writing the stub straight to that path truncates their real binary.
write_shim() {
  local path="${CASE_ROOT}/bin/$1"
  case "$CASE_ROOT" in
    "${RUNS}"/?*) ;;
    *) die "refusing to write a shim outside the run dir: $path" ;;
  esac
  rm -f "$path"
  printf '%s\n' "$2" >"$path"
  chmod +x "$path"
}

# A shim that always fails, for staging a missing or broken tool.
broken_shim() {
  write_shim "$1" $'#!/bin/sh\nexit 127'
}

# --- cases -----------------------------------------------------------------

case_up_to_date() {
  detect_claude
  install_skills
  make_due
  local head_before out
  head_before="$(git -C "$CLONE" rev-parse HEAD)"
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_eq "HEAD" "$head_before" "$(git -C "$CLONE" rev-parse HEAD)"
}

case_behind() {
  detect_claude
  install_skills
  push_skill zz-harness-skill
  make_due
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_eq "HEAD" "$(git -C "$PUSHER" rev-parse HEAD)" "$(git -C "$CLONE" rev-parse HEAD)"
  assert_link "${HOME}/.claude/skills/zz-harness-skill"
  assert_link "${HOME}/.agents/skills/zz-harness-skill"
}

case_replay_after_manual_pull() {
  detect_claude
  install_skills
  push_skill zz-harness-skill
  git -C "$CLONE" pull -q --ff-only
  make_due
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_link "${HOME}/.claude/skills/zz-harness-skill"
}

case_fresh_install_no_replay() {
  detect_claude
  install_skills
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_not_contains "log" "$(log_text)" "Agents dir ->"
}

case_partial_rerun() {
  detect_claude
  install_skills
  install_rules
  push_skill zz-harness-skill
  git -C "$CLONE" pull -q --ff-only
  install_skills
  make_due
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_contains "log" "$(log_text)" "Rules ->"
  assert_not_contains "log" "$(log_text)" "Skills ->"
}

case_two_targets() {
  detect_claude
  install_skills
  install_skills --skills-dir "${HOME}/other/skills"
  push_skill zz-harness-skill
  make_due
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_link "${HOME}/.claude/skills/zz-harness-skill"
  assert_link "${HOME}/other/skills/zz-harness-skill"
}

case_target_removed() {
  detect_claude
  install_skills
  install_skills --skills-dir "${HOME}/other/skills"
  rm -rf "${HOME}/other/skills"
  push_skill zz-harness-skill
  make_due
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_eq "dropped record" "" "$(record_line install.sh "${HOME}/other/skills")"
  assert_file_missing "${HOME}/other/skills"
  assert_link "${HOME}/.claude/skills/zz-harness-skill"
}

case_dirty() {
  detect_claude
  install_skills
  echo "local edit" >>"${CLONE}/README.md"
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "uncommitted changes"
  assert_message_contains "$out" "$CLONE"

  make_due
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"

  git -C "$CLONE" checkout -q -- README.md
  make_due
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"

  echo "local edit again" >>"${CLONE}/README.md"
  make_due
  out="$(run_hook)"
  assert_message_contains "$out" "uncommitted changes"
}

case_second_error_reported() {
  detect_claude
  install_skills
  echo "local edit" >>"${CLONE}/README.md"
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "uncommitted changes"

  git -C "$CLONE" commit -qam "local commit"
  push_skill zz-harness-skill
  make_due
  out="$(run_hook)"
  assert_message_contains "$out" "commits that are not on"
}

case_untracked_conflict() {
  detect_claude
  install_skills
  push_file conflict.txt "from upstream"
  printf 'mine\n' >"${CLONE}/conflict.txt"
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "conflict.txt"
  assert_message_contains "$out" "could not update"
}

case_replay_failure() {
  detect_claude
  install_skills
  push_skill zz-harness-skill
  chmod 500 "${HOME}/.claude/skills"
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "install.sh failed"
  assert_message_contains "$out" "Run it by hand"

  make_due
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_contains "log" "$(log_text)" "Skills ->"

  chmod 700 "${HOME}/.claude/skills"
  make_due
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_link "${HOME}/.claude/skills/zz-harness-skill"
}

case_diverged() {
  detect_claude
  install_skills
  printf 'local\n' >"${CLONE}/local-only.txt"
  git -C "$CLONE" add local-only.txt
  git -C "$CLONE" commit -qm "local commit"
  push_skill zz-harness-skill
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "commits that are not on"
  assert_message_contains "$out" "log @{u}.."
}

case_non_default_branch() {
  detect_claude
  install_skills
  ensure_pusher
  git -C "$PUSHER" checkout -qb feature
  git -C "$PUSHER" push -q -u origin feature
  git -C "$CLONE" fetch -q
  git -C "$CLONE" checkout -q -b feature --track origin/feature
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "does not track"
  assert_message_contains "$out" "checkout main"
}

case_other_name_tracking_default() {
  detect_claude
  install_skills
  git -C "$CLONE" checkout -q -b work --track origin/main
  push_skill zz-harness-skill
  make_due
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_link "${HOME}/.claude/skills/zz-harness-skill"
}

case_detached() {
  detect_claude
  install_skills
  git -C "$CLONE" checkout -q --detach HEAD
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "detached HEAD"
  assert_message_contains "$out" "checkout main"
}

case_no_upstream() {
  detect_claude
  install_skills
  git -C "$CLONE" branch --unset-upstream
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "no upstream"
  assert_message_contains "$out" "--set-upstream-to origin/main"
}

case_offline() {
  detect_claude
  install_skills
  git -C "$CLONE" remote set-url origin /nonexistent-remote.git
  make_due
  local out now stamp
  now="$(date +%s)"
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  stamp="$(cat "${STATE}/stamp")"
  if [ "$((stamp - now))" -gt 3660 ] || [ "$((stamp - now))" -lt 3540 ]; then
    fail "stamp: expected about an hour ahead, got $((stamp - now))s"
  fi
  [ -f "${STATE}/offline-since" ] || fail "offline-since was not created"
}

case_offline_for_a_week() {
  detect_claude
  install_skills
  local url out
  url="$(git -C "$CLONE" remote get-url origin)"
  git -C "$CLONE" remote set-url origin /nonexistent-remote.git
  make_due
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"

  printf '%s\n' "$(( $(date +%s) - 8 * 86400 ))" >"${STATE}/offline-since"
  make_due
  out="$(run_hook)"
  assert_message_contains "$out" "for a week"
  assert_message_contains "$out" "/nonexistent-remote.git"

  make_due
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"

  git -C "$CLONE" remote set-url origin "$url"
  make_due
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_file_missing "${STATE}/offline-since"
}

case_fetch_hang() {
  detect_claude
  install_skills
  write_shim ssh $'#!/bin/sh\nsleep 30'
  git -C "$CLONE" remote set-url origin ssh://localhost/nope.git
  make_due
  local started ended out
  started="$(date +%s)"
  out="$(run_hook)"
  ended="$(date +%s)"
  assert_stdout_is '{}' "$out"
  if [ "$((ended - started))" -gt 9 ]; then
    fail "fetch watchdog: took $((ended - started))s"
  fi
  [ -f "${STATE}/offline-since" ] || fail "a hung fetch should count as offline"
}

case_ssh_guard() {
  detect_claude
  install_skills
  local log="${CASE_ROOT}/ssh-argv"
  write_shim ssh "$(printf '#!/bin/sh\necho "$@" >> %s\nenv | grep GIT_SSH_COMMAND >> %s.env\nexit 255' \
    "$log" "$log")"
  cp "${CASE_ROOT}/bin/ssh" "${CASE_ROOT}/bin/plink"
  git -C "$CLONE" remote set-url origin ssh://localhost/nope.git

  make_due
  run_hook >/dev/null
  assert_contains "ssh argv" "$(cat "$log" 2>/dev/null)" "-o BatchMode=yes"
  assert_contains "ssh argv" "$(cat "$log" 2>/dev/null)" "-o ConnectTimeout=5"

  # A wrapper we do not recognise gets no flags: plink rejects -o.
  : >"$log"
  git -C "$CLONE" config core.sshCommand "${CASE_ROOT}/bin/plink"
  make_due
  run_hook >/dev/null
  assert_not_contains "plink argv" "$(cat "$log" 2>/dev/null)" "-o BatchMode=yes"
  git -C "$CLONE" config --unset core.sshCommand

  # GIT_SSH is next in git's precedence, so we must not export over it.
  : >"$log"
  : >"${log}.env"
  make_due
  export GIT_SSH="${CASE_ROOT}/bin/ssh"
  run_hook >/dev/null
  unset GIT_SSH
  assert_eq "GIT_SSH_COMMAND seen by GIT_SSH" "" "$(cat "${log}.env" 2>/dev/null)"
}

case_throttled() {
  detect_claude
  install_skills
  make_due
  run_hook >/dev/null
  printf 'sentinel\n' >"${STATE}/log"
  printf '%s\n' "$(( $(date +%s) + 99999 ))" >"${STATE}/stamp"
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_eq "log untouched" "sentinel" "$(log_text)"
}

case_lock_held() {
  detect_claude
  install_skills
  make_due
  mkdir -p "${STATE}/lock"
  printf '%s\n' "$(date +%s)" >"${STATE}/lock/ts"
  printf 'sentinel\n' >"${STATE}/log"
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_eq "log untouched" "sentinel" "$(log_text)"
  [ -d "${STATE}/lock" ] || fail "someone else's lock was removed"
}

case_stale_lock() {
  detect_claude
  install_skills
  make_due
  mkdir -p "${STATE}/lock"
  printf '%s\n' "$(( $(date +%s) - 120 ))" >"${STATE}/lock/ts"
  printf 'sentinel\n' >"${STATE}/log"
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_not_contains "log" "$(log_text)" "sentinel"
  [ -d "${STATE}/lock" ] && fail "the lock should be released at exit"
  return 0
}

case_state_in_worktree() {
  detect_claude
  install_skills
  git -C "$CLONE" worktree add -q --detach "${CASE_ROOT}/wt" >/dev/null 2>&1
  bash "${CASE_ROOT}/wt/lib/auto-update.sh" --json >/dev/null
  [ -d "${CLONE}/.git/worktrees/wt/agent-toolkit" ] \
    || fail "expected state under .git/worktrees/wt/agent-toolkit"
}

case_state_in_submodule() {
  detect_claude
  local super="${CASE_ROOT}/super"
  mkdir -p "$super"
  git -c init.defaultBranch=main init -q "$super"
  git -C "$super" -c protocol.file.allow=always submodule add -q \
    "${CASE_ROOT}/remote.git" sub >/dev/null 2>&1
  git -C "$super" commit -qm "add submodule"
  bash "${super}/sub/lib/auto-update.sh" --json >/dev/null
  [ -d "${super}/.git/modules/sub/agent-toolkit" ] \
    || fail "expected state under .git/modules/sub/agent-toolkit"
}

case_copies_recorded() {
  detect_claude
  install_skills
  # Stage what a Windows install leaves behind: the record says copies, and the
  # entries are real directories the installer will not touch.
  local target="${HOME}/.claude/skills" entry name
  awk -F '\t' 'BEGIN { OFS = "\t" } { $6 = 1; print }' "${STATE}/invocations" \
    >"${STATE}/invocations.new"
  mv "${STATE}/invocations.new" "${STATE}/invocations"
  for entry in "$target"/*; do
    name="$(basename "$entry")"
    rm -rf "$entry"
    mkdir -p "${target}/${name}"
    : >"${target}/${name}/SKILL.md"
  done

  push_skill zz-harness-skill
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "holds copies rather than links"
  assert_message_contains "$out" "--force"
  assert_message_contains "$out" "$target"
  assert_eq "copies flag stays set" "1" "$(record_field install.sh "$target" 6)"

  push_skill zz-harness-skill-two
  make_due
  out="$(run_hook)"
  assert_message_contains "$out" "holds copies rather than links"
}

case_two_reasons() {
  detect_claude
  install_skills
  install_skills --skills-dir "${HOME}/other/skills"
  local other="${HOME}/other/skills" entry name
  awk -F '\t' -v t="$other" 'BEGIN { OFS = "\t" } $4 == t { $6 = 1 } { print }' \
    "${STATE}/invocations" >"${STATE}/invocations.new"
  mv "${STATE}/invocations.new" "${STATE}/invocations"
  for entry in "$other"/*; do
    name="$(basename "$entry")"
    rm -rf "$entry"
    mkdir -p "${other}/${name}"
  done
  chmod 500 "${HOME}/.claude/skills"

  push_skill zz-harness-skill
  make_due
  local out msg lines
  out="$(run_hook)"
  msg="$(json_message "$out")"
  lines="$(printf '%s\n' "$msg" | grep -c .)"
  assert_eq "one line per reason" "2" "$lines"
  assert_contains "message" "$msg" "install.sh failed"
  assert_contains "message" "$msg" "holds copies rather than links"
  chmod 700 "${HOME}/.claude/skills"
}

case_feedback_is_json_escaped() {
  detect_claude
  install_skills
  push_file 'we"ird.txt' "from upstream"
  printf 'mine\n' >"${CLONE}/we\"ird.txt"
  make_due
  local out msg
  out="$(run_hook)"
  msg="$(json_message "$out")"
  if [ -z "$msg" ]; then
    fail "stdout did not parse as JSON: $out"
  fi
  assert_contains "message" "$msg" 'we"ird.txt'
}

case_moved_clone() {
  detect_claude
  install_skills
  mv "$CLONE" "${CASE_ROOT}/clone2"
  CLONE="${CASE_ROOT}/clone2"
  STATE="${CLONE}/.git/agent-toolkit"
  install_skills
  assert_eq "one handler" "1" "$(hook_count)"
  assert_contains "hook command" "$(settings_get hooks.SessionStart.0.hooks.0.command)" \
    "${CASE_ROOT}/clone2/lib/auto-update.sh"
  # links still target the old path and count as foreign, so only --force re-points them
  assert_link_target "${HOME}/.agents/skills/handover" "${CASE_ROOT}/clone/skills/handover"
  install_skills --force
  assert_link_target "${HOME}/.agents/skills/handover" "${CLONE}/skills/handover"
}

case_drifted_hook_entry() {
  detect_claude
  install_skills
  /usr/bin/python3 - "$(settings_file)" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
group = data["hooks"]["SessionStart"][0]
group["matcher"] = "startup|resume"
group["hooks"][0]["timeout"] = 99
group["hooks"][0]["extra"] = True
json.dump(data, open(path, "w"), indent=2)
PY
  push_skill zz-harness-skill
  make_due
  run_hook >/dev/null
  assert_eq "one handler" "1" "$(hook_count)"
  assert_eq "timeout" "10" "$(settings_get hooks.SessionStart.0.hooks.0.timeout)"
  assert_eq "matcher kept" "startup|resume" "$(settings_get hooks.SessionStart.0.matcher)"
  assert_eq "extra key dropped" "" "$(settings_get hooks.SessionStart.0.hooks.0.extra)"
}

case_opt_out_and_back_in() {
  detect_claude
  install_skills
  assert_eq "registered" "1" "$(hook_count)"

  install_skills --no-auto-update
  assert_contains "installer output" "$OUT" "opted out"
  assert_eq "removed" "0" "$(hook_count)"
  [ -f "${STATE}/opt-out" ] || fail "opt-out marker was not created"

  install_rules
  assert_contains "installer output" "$OUT" "opted out"
  assert_eq "still removed" "0" "$(hook_count)"

  make_due
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_not_contains "log" "$(log_text)" "Agents dir ->"

  install_skills --auto-update
  assert_eq "back" "1" "$(hook_count)"
  assert_file_missing "${STATE}/opt-out"
}

case_claude_not_detected() {
  install_skills
  assert_contains "installer output" "$OUT" "no Claude Code found"
  assert_link "${HOME}/.claude/skills/handover"
  assert_file_missing "$(settings_file)"
}

case_git_unusable() {
  detect_claude
  broken_shim git
  install_skills
  assert_eq "installer exit code" "0" "$INSTALL_RC"
  assert_contains "installer output" "$OUT" "not a git work tree"
  assert_link "${HOME}/.claude/skills/handover"
  assert_file_missing "${STATE}/invocations"
}

case_symlinked_clone_path() {
  detect_claude
  ln -s "$CLONE" "${CASE_ROOT}/clone-link"
  bash "${CASE_ROOT}/clone-link/install.sh" >>"${CASE_ROOT}/install.log" 2>&1
  assert_link_target "${HOME}/.agents/skills/handover" "${CLONE}/skills/handover"

  # What an install from before physical REPO_DIR left behind: links through
  # the symlinked path, which the installer must re-point rather than skip.
  local entry name out
  for entry in "${HOME}/.agents/skills"/*; do
    name="$(basename "$entry")"
    rm -f "$entry"
    ln -s "${CASE_ROOT}/clone-link/skills/${name}" "$entry"
  done
  OUT="$(bash "${CASE_ROOT}/clone-link/install.sh" 2>&1)"
  assert_not_contains "installer output" "$OUT" "skip"
  assert_link_target "${HOME}/.agents/skills/handover" "${CLONE}/skills/handover"

  push_skill zz-harness-skill
  make_due
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_not_contains "log" "$(log_text)" "skip"
  assert_link "${HOME}/.claude/skills/zz-harness-skill"
}

case_non_claude_skills_dir() {
  detect_claude
  install_skills --skills-dir "${HOME}/proj/.claude/skills"
  assert_contains "installer output" "$OUT" "not Claude Code's own dir"
  assert_contains "installer output" "$OUT" "lib/auto-update.sh"
  assert_eq "nothing registered" "0" "$(hook_count)"
}

case_no_upstream_at_install() {
  detect_claude
  git -C "$CLONE" branch --unset-upstream
  install_skills
  assert_contains "installer output" "$OUT" "no upstream"
  assert_eq "nothing registered" "0" "$(hook_count)"
}

case_detached_at_install() {
  detect_claude
  git -C "$CLONE" checkout -q --detach HEAD
  install_skills
  assert_contains "installer output" "$OUT" "detached HEAD"
  assert_not_contains "installer output" "$OUT" "--set-upstream-to"
  assert_eq "nothing registered" "0" "$(hook_count)"
}

case_apostrophe_in_clone_path() {
  detect_claude
  mkdir -p "${CASE_ROOT}/it's"
  git clone -q "${CASE_ROOT}/remote.git" "${CASE_ROOT}/it's/clone"
  CLONE="${CASE_ROOT}/it's/clone"
  STATE="${CLONE}/.git/agent-toolkit"
  install_skills
  assert_contains "installer output" "$OUT" "apostrophe"
  assert_contains "installer output" "$OUT" "hooks.SessionStart"
  assert_eq "nothing registered" "0" "$(hook_count)"
}

case_settings_created() {
  detect_claude
  install_skills
  assert_eq "one handler" "1" "$(hook_count)"
  assert_eq "one group" "1" "$(group_count)"
  assert_eq "matcher" "startup" "$(settings_get hooks.SessionStart.0.matcher)"
  assert_eq "timeout" "10" "$(settings_get hooks.SessionStart.0.hooks.0.timeout)"
  assert_eq "top-level keys" '["hooks"]' "$(top_level_keys)"
}

case_settings_keeps_foreign_hooks() {
  detect_claude
  mkdir -p "${HOME}/.claude"
  cat >"$(settings_file)" <<'JSON'
{
  "model": "opus",
  "hooks": {
    "Stop": [{ "matcher": "", "hooks": [{ "type": "command", "command": "echo stop" }] }],
    "SessionStart": [
      { "matcher": "startup", "hooks": [{ "type": "command", "command": "echo foreign" }] }
    ]
  }
}
JSON
  install_skills
  assert_eq "one handler" "1" "$(hook_count)"
  assert_eq "model kept" "opus" "$(settings_get model)"
  assert_contains "Stop kept" "$(settings_get hooks.Stop)" "echo stop"
  assert_contains "foreign group kept" "$(settings_get hooks.SessionStart.0)" "echo foreign"
  assert_contains "ours appended" "$(settings_get hooks.SessionStart.1)" "lib/auto-update.sh"
}

case_settings_unparsable() {
  detect_claude
  mkdir -p "${HOME}/.claude"
  printf '{ nope' >"$(settings_file)"
  install_skills
  assert_contains "installer output" "$OUT" "not valid JSON"
  assert_contains "installer output" "$OUT" "hooks.SessionStart"
  assert_eq "file untouched" '{ nope' "$(cat "$(settings_file)")"
}

case_interpreter_fallthrough() {
  detect_claude
  broken_shim python3
  if [ -n "$REAL_NODE" ]; then
    ln -sf "$REAL_NODE" "${CASE_ROOT}/bin/node"
    install_skills
    assert_eq "node did the merge" "1" "$(hook_count)"
    rm -f "$(settings_file)"
    broken_shim node
    "$REAL_NODE" -v >/dev/null 2>&1 || fail "the node shim clobbered $REAL_NODE"
  else
    echo "    (no node available, skipping the node leg)"
  fi
  install_skills
  assert_eq "jq did the merge" "1" "$(hook_count)"
}

case_no_interpreter() {
  detect_claude
  broken_shim python3
  broken_shim node
  broken_shim jq
  install_skills
  assert_contains "installer output" "$OUT" "no working python3, node or jq"
  assert_contains "installer output" "$OUT" "hooks.SessionStart"
  assert_file_missing "$(settings_file)"
}

case_settings_written_only_on_change() {
  detect_claude
  install_skills
  local before
  before="$(mtime "$(settings_file)")"
  sleep 1
  install_skills
  assert_contains "installer output" "$OUT" "Already registered"
  assert_eq "settings mtime" "$before" "$(mtime "$(settings_file)")"
}

case_settings_symlinked() {
  detect_claude
  mkdir -p "${HOME}/dotfiles" "${HOME}/.claude"
  printf '{ "model": "opus" }\n' >"${HOME}/dotfiles/settings.json"
  chmod 600 "${HOME}/dotfiles/settings.json"
  ln -s ../dotfiles/settings.json "$(settings_file)"
  install_skills
  [ -L "$(settings_file)" ] || fail "settings.json is no longer a symlink"
  assert_eq "one handler" "1" "$(hook_count)"
  assert_contains "written through the link" "$(cat "${HOME}/dotfiles/settings.json")" \
    "lib/auto-update.sh"
  assert_eq "mode kept" "600" "$(mode "${HOME}/dotfiles/settings.json")"
}

case_term_releases_the_lock() {
  detect_claude
  install_skills
  write_shim ssh $'#!/bin/sh\nsleep 30'
  git -C "$CLONE" remote set-url origin ssh://localhost/nope.git
  make_due
  local pid started ended
  started="$(date +%s)"
  bash "${CLONE}/lib/auto-update.sh" --json >/dev/null &
  pid=$!
  sleep 2
  kill -TERM "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  ended="$(date +%s)"
  [ -d "${STATE}/lock" ] && fail "the lock should be released on TERM"
  if [ "$((ended - started))" -gt 5 ]; then
    fail "TERM should end the run, it took $((ended - started))s"
  fi
  return 0
}

case_plain_output_mode() {
  detect_claude
  install_skills
  echo "local edit" >>"${CLONE}/README.md"
  make_due
  local out
  out="$(run_hook_plain)"
  assert_contains "plain output" "$out" "uncommitted changes"
  assert_not_contains "plain output" "$out" "systemMessage"

  make_due
  out="$(run_hook_plain)"
  assert_eq "plain output when silent" "" "$out"
}

CASES="
up_to_date
behind
replay_after_manual_pull
fresh_install_no_replay
partial_rerun
two_targets
target_removed
dirty
second_error_reported
untracked_conflict
replay_failure
diverged
non_default_branch
other_name_tracking_default
detached
no_upstream
offline
offline_for_a_week
fetch_hang
ssh_guard
throttled
lock_held
stale_lock
term_releases_the_lock
state_in_worktree
state_in_submodule
copies_recorded
two_reasons
feedback_is_json_escaped
moved_clone
drifted_hook_entry
opt_out_and_back_in
claude_not_detected
git_unusable
symlinked_clone_path
non_claude_skills_dir
no_upstream_at_install
detached_at_install
apostrophe_in_clone_path
settings_created
settings_keeps_foreign_hooks
settings_unparsable
interpreter_fallthrough
no_interpreter
settings_written_only_on_change
settings_symlinked
plain_output_mode
"

# The clone under test is the working tree, not git history: the harness has to
# see uncommitted work. test/ is left out, it is not installed anyway and it
# holds this run's own output.
build_template() {
  local src="${RUNS}/_src"
  mkdir -p "$src"
  (cd "$REPO_ROOT" && tar --exclude './.git' --exclude './.agents' --exclude './.idea' \
      --exclude './.superpowers' --exclude './test' --exclude '.DS_Store' -cf - .) \
    | (cd "$src" && tar -xf -)
  git -c init.defaultBranch=main init -q "$src" || die "git init failed in $src"
  is_repo_root "$src" || die "$src did not become a repo"
  git -C "$src" add -A || die "git add failed in $src"
  git -C "$src" commit -qm "harness snapshot" || die "git commit failed in $src"
  git clone -q --bare "$src" "$TEMPLATE" || die "could not build the template remote"
}

mkdir -p "$RUNS"
export HOME="${RUNS}/_home"
mkdir -p "$HOME"
export PATH="$BASE_PATH"
build_template

WANTED="$*"
for name in $CASES; do
  if [ -n "$WANTED" ]; then
    case " $WANTED " in *" $name "*) ;; *) continue ;; esac
  fi
  new_case "$name"
  "case_${name}"
  RAN=$((RAN + 1))
  if [ "$CASE_FAILS" -gt 0 ]; then
    TOTAL_FAILS=$((TOTAL_FAILS + 1))
  fi
done

echo
if [ "$TOTAL_FAILS" -eq 0 ]; then
  echo "All ${RAN} cases passed. Output: ${RUNS}"
  exit 0
fi
echo "${TOTAL_FAILS} of ${RAN} cases failed. Output: ${RUNS}"
exit 1
