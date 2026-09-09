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

# Real git, python3, node and jq are resolved before PATH is narrowed to
# BASE_PATH: git lives in BASE_PATH itself, and python3/node/jq are captured
# as absolute paths from the caller's PATH. Cases stage "no git" and "no
# interpreter" as failing shims in the case's own bin dir, because the
# installers test what works rather than what exists; the harness's own JSON
# reads go through the resolved $PYTHON so those shims cannot reach them.
# node and jq are not reliably on BASE_PATH, so a case that needs one links
# the real binary in and skips its leg when there is none.
BASE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
PYTHON="$(command -v python3 2>/dev/null || true)"
REAL_NODE="$(command -v node 2>/dev/null || true)"
REAL_JQ="$(command -v jq 2>/dev/null || true)"

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

# A CLT-less macOS python3 stub pops a blocking "install developer tools"
# dialog instead of failing fast; bound the probe so the harness can't hang on
# it before the first case even runs.
python_usable() {
  [ -n "$PYTHON" ] || return 1
  local pid ticks=0
  "$PYTHON" -c 'import json' >/dev/null 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ticks" -ge 30 ]; then
      pkill -P "$pid" 2>/dev/null
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 1
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done
  wait "$pid"
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

# A hook that dies on line 1 satisfies any assertion about what is absent. The
# stamp is the cheapest proof a run got past the throttle.
assert_ran() {
  local due
  due="$(cat "${STATE}/stamp" 2>/dev/null)"
  case "$due" in ''|*[!0-9]*) fail "no stamp: the hook never ran"; return 0 ;; esac
  [ "$due" -gt "$(date +%s)" ] || fail "the hook left a stale stamp: $due"
}

# --- helpers ---------------------------------------------------------------

json_message() {
  printf '%s' "$1" | "$PYTHON" -c \
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
  "$PYTHON" - "$file" <<'PY' 2>/dev/null
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
  "$PYTHON" - "$(settings_file)" "$1" <<'PY' 2>/dev/null
import json, sys
node = json.load(open(sys.argv[1]))
for part in sys.argv[2].split("."):
    node = node[int(part)] if isinstance(node, list) else node[part]
print(node if not isinstance(node, (dict, list)) else json.dumps(node))
PY
}

group_count() {
  "$PYTHON" - "$(settings_file)" <<'PYX' 2>/dev/null
import json, sys
print(len(json.load(open(sys.argv[1])).get("hooks", {}).get("SessionStart", [])))
PYX
}

top_level_keys() {
  "$PYTHON" - "$(settings_file)" <<'PYX' 2>/dev/null
import json, sys
print(json.dumps(sorted(json.load(open(sys.argv[1])).keys())))
PYX
}

# The pasteable handler out of the last installer run, as its command string.
snippet_command() {
  printf '%s\n' "$OUT" | "$PYTHON" -c '
import json, sys
lines = sys.stdin.read().splitlines()
start = next(i for i, l in enumerate(lines) if l.strip() == "{")
end = next(i for i in range(start, len(lines)) if lines[i].strip() == "}")
print(json.loads("\n".join(lines[start:end + 1]))["hooks"][0]["command"])
'
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

# One settings_merge call on its own, for the shapes no installer run reaches.
settings_merge_rc() {
  ( . "${CLONE}/lib/install-utils.sh"
    settings_merge "$1" "$2" "bash '${CLONE}/lib/auto-update.sh' --json" )
}

# A lock older than the stale threshold, by a margin.
stale_ts() {
  printf '%s' "$(( $(date +%s) - 4000 ))"
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
  assert_ran
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
  assert_ran
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

# A failed fast-forward means nothing moved, so the recorded installers must not
# run: every message they produce claims the clone was updated.
case_conflict_skips_replay() {
  detect_claude
  install_skills
  push_skill zz-harness-skill
  git -C "$CLONE" pull -q --ff-only
  push_file conflict.txt "from upstream"
  printf 'mine\n' >"${CLONE}/conflict.txt"
  make_due
  local out
  out="$(run_hook)"
  assert_message_contains "$out" "could not update"
  assert_message_contains "$out" "conflict.txt"
  assert_not_contains "message" "$(json_message "$out")" "agent-toolkit updated"
  assert_file_missing "${HOME}/.claude/skills/zz-harness-skill"
  assert_not_contains "log" "$(log_text)" "Skills ->"
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

case_offline_url_redacted() {
  detect_claude
  install_skills
  git -C "$CLONE" remote set-url origin https://alice:s3cr3t@no-such-host.invalid/x.git
  make_due
  run_hook >/dev/null
  printf '%s\n' "$(( $(date +%s) - 8 * 86400 ))" >"${STATE}/offline-since"
  make_due
  local out msg reason
  out="$(run_hook)"
  msg="$(json_message "$out")"
  reason="$(cat "${STATE}/reason" 2>/dev/null)"
  assert_contains "message" "$msg" "for a week"
  assert_contains "message" "$msg" "https://no-such-host.invalid/x.git"
  assert_not_contains "message" "$msg" "s3cr3t"
  assert_not_contains "message" "$msg" "alice"
  assert_not_contains "reason" "$reason" "s3cr3t"
  assert_not_contains "reason" "$reason" "alice"
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
  assert_contains "plink argv" "$(cat "$log" 2>/dev/null)" "git-upload-pack"
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
  assert_ran
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
  assert_ran
  assert_eq "log untouched" "sentinel" "$(log_text)"
  [ -d "${STATE}/lock" ] || fail "someone else's lock was removed"
}

case_stale_lock() {
  detect_claude
  install_skills
  make_due
  mkdir -p "${STATE}/lock"
  printf '%s\n' "$(stale_ts)" >"${STATE}/lock/ts"
  printf 'sentinel\n' >"${STATE}/log"
  local out
  out="$(run_hook)"
  assert_stdout_is '{}' "$out"
  assert_not_contains "log" "$(log_text)" "sentinel"
  [ -d "${STATE}/lock" ] && fail "the lock should be released at exit"
  return 0
}

# The trap must recognise its own lock: a successor that took over after we were
# declared stale owns the directory, and removing it would let a third run in.
case_lock_not_ours() {
  detect_claude
  install_skills
  write_shim ssh $'#!/bin/sh\nsleep 30'
  git -C "$CLONE" remote set-url origin ssh://localhost/nope.git
  make_due
  local pid mine
  bash "${CLONE}/lib/auto-update.sh" --json >/dev/null &
  pid=$!
  sleep 2
  mine="$(cat "${STATE}/lock/owner" 2>/dev/null)"
  [ -n "$mine" ] || fail "the run recorded no owner token"
  printf 'someone-else\n' >"${STATE}/lock/owner"
  kill -TERM "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  [ -d "${STATE}/lock" ] || fail "a lock we do not own was removed"
  assert_eq "lock owner" "someone-else" "$(cat "${STATE}/lock/owner" 2>/dev/null)"

  # Takeover goes by the timestamp, not the token: someone else's stale lock is
  # still ours to claim.
  printf '%s\n' "$(stale_ts)" >"${STATE}/lock/ts"
  make_due
  run_hook >/dev/null
  assert_file_missing "${STATE}/lock"
  return 0
}

case_lock_takeover_loser() {
  detect_claude
  install_skills
  make_due
  mkdir -p "${STATE}/lock"
  printf '%s\n' "$(stale_ts)" >"${STATE}/lock/ts"
  printf 'someone-else\n' >"${STATE}/lock/owner"
  chmod 400 "${STATE}/lock/owner"
  printf 'sentinel\n' >"${STATE}/log"
  local out
  out="$(run_hook)"
  chmod 600 "${STATE}/lock/owner"
  assert_stdout_is '{}' "$out"
  assert_eq "log untouched" "sentinel" "$(log_text)"
  assert_eq "lock owner" "someone-else" "$(cat "${STATE}/lock/owner" 2>/dev/null)"
  [ -d "${STATE}/lock" ] || fail "a lock we did not win was removed"
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
  "$PYTHON" - "$(settings_file)" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
group = data["hooks"]["SessionStart"][0]
group["matcher"] = "startup|resume"
group["hooks"][0]["timeout"] = 3
group["hooks"][0]["extra"] = True
json.dump(data, open(path, "w"), indent=2)
PY
  push_skill zz-harness-skill
  make_due
  run_hook >/dev/null
  assert_eq "one handler" "1" "$(hook_count)"
  assert_eq "lowered timeout reset" "20" "$(settings_get hooks.SessionStart.0.hooks.0.timeout)"
  assert_eq "matcher kept" "startup|resume" "$(settings_get hooks.SessionStart.0.matcher)"
  assert_eq "extra key dropped" "" "$(settings_get hooks.SessionStart.0.hooks.0.extra)"

  # A timeout the user raised is theirs to keep: the daily replay must not
  # take their escape hatch away.
  "$PYTHON" - "$(settings_file)" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
data["hooks"]["SessionStart"][0]["hooks"][0]["timeout"] = 99
json.dump(data, open(path, "w"), indent=2)
PY
  push_skill zz-harness-skill-2
  make_due
  run_hook >/dev/null
  assert_eq "raised timeout kept" "99" "$(settings_get hooks.SessionStart.0.hooks.0.timeout)"
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

  make_due
  run_hook >/dev/null
  assert_ran
}

# An explicit opt-out has to reach the hook even when git cannot read the
# clone, or the entry outlives the clone and fails at every session start.
case_opt_out_without_git() {
  detect_claude
  install_skills
  assert_eq "registered" "1" "$(hook_count)"
  broken_shim git
  install_skills --no-auto-update
  assert_eq "installer exit code" "0" "$INSTALL_RC"
  assert_contains "installer output" "$OUT" "removed our hook"
  assert_contains "installer output" "$OUT" "not recorded"
  assert_eq "removed" "0" "$(hook_count)"
}

# The hook names the clone, so opting out from any install of it removes it,
# a project's skills dir included.
case_opt_out_from_other_target() {
  detect_claude
  install_skills
  assert_eq "registered" "1" "$(hook_count)"
  install_skills --skills-dir "${HOME}/proj/.claude/skills" --no-auto-update
  assert_contains "installer output" "$OUT" "removed our hook"
  assert_eq "removed" "0" "$(hook_count)"
  [ -f "${STATE}/opt-out" ] || fail "opt-out marker was not created"
}

case_marker_write_fails() {
  detect_claude
  install_skills
  assert_eq "registered" "1" "$(hook_count)"

  chmod 500 "$STATE"
  install_skills --no-auto-update
  chmod 700 "$STATE"
  assert_eq "installer exit status" "0" "$INSTALL_RC"
  assert_contains "installer output" "$OUT" "could not record the opt-out"
  assert_eq "handler removed" "0" "$(hook_count)"
  assert_file_missing "${STATE}/opt-out"

  : >"${STATE}/opt-out"
  chmod 500 "$STATE"
  install_skills --auto-update
  chmod 700 "$STATE"
  assert_eq "installer exit status" "0" "$INSTALL_RC"
  assert_contains "installer output" "$OUT" "could not clear the opt-out"
  assert_eq "handler registered" "1" "$(hook_count)"
  [ -e "${STATE}/opt-out" ] || fail "the marker we could not remove is gone"
  rm -f "${STATE}/opt-out"
}

# Every other registering case goes through install.sh, and the rules installer
# has its own target check.
case_rules_installer_registers() {
  detect_claude
  install_rules
  assert_contains "installer output" "$OUT" "Auto-update: on"
  assert_eq "one handler" "1" "$(hook_count)"
  assert_contains "hook command" "$(settings_get hooks.SessionStart.0)" "${CLONE}/lib/auto-update.sh"
  local target
  target="$(cd "${HOME}/.claude/rules" && pwd -P)"
  assert_eq "recorded flag" "--rules-dir" \
    "$(record_field install-opinionated-rules.sh "$target" 3)"
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

  # Once the clone has its hook, that hook replays this install too, and the
  # advice to add a second one would be wrong.
  install_skills
  assert_eq "registered" "1" "$(hook_count)"
  install_skills --skills-dir "${HOME}/proj/.claude/skills"
  assert_contains "installer output" "$OUT" "replays this install too"
  assert_not_contains "installer output" "$OUT" "not Claude Code's own dir"
  assert_eq "still one handler" "1" "$(hook_count)"
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

case_snippet_json_escaped() {
  detect_claude
  mkdir -p "${CASE_ROOT}/q\"uote"
  git clone -q "${CASE_ROOT}/remote.git" "${CASE_ROOT}/q\"uote/clone"
  CLONE="${CASE_ROOT}/q\"uote/clone"
  STATE="${CLONE}/.git/agent-toolkit"
  install_skills
  assert_eq "registered" "1" "$(hook_count)"
  assert_eq "registered command" "bash '${CLONE}/lib/auto-update.sh' --json" \
    "$(settings_get hooks.SessionStart.0.hooks.0.command)"

  broken_shim python3
  broken_shim node
  broken_shim jq
  install_skills
  assert_contains "installer output" "$OUT" "no working python3, node or jq"
  assert_eq "snippet command" "bash '${CLONE}/lib/auto-update.sh' --json" "$(snippet_command)"
}

case_apostrophe_in_replay_advice() {
  detect_claude
  mkdir -p "${CASE_ROOT}/it's"
  git clone -q "${CASE_ROOT}/remote.git" "${CASE_ROOT}/it's/clone"
  CLONE="${CASE_ROOT}/it's/clone"
  STATE="${CLONE}/.git/agent-toolkit"
  install_skills
  push_skill zz-harness-skill
  chmod 500 "${HOME}/.claude/skills"
  make_due
  local out
  out="$(run_hook)"
  chmod 700 "${HOME}/.claude/skills"
  assert_message_contains "$out" "install.sh failed"
  assert_message_contains "$out" "cannot be safely quoted"
  assert_not_contains "message" "$(json_message "$out")" "bash '"
}

case_settings_created() {
  detect_claude
  install_skills
  assert_eq "one handler" "1" "$(hook_count)"
  assert_eq "one group" "1" "$(group_count)"
  assert_eq "matcher" "startup" "$(settings_get hooks.SessionStart.0.matcher)"
  assert_eq "timeout" "20" "$(settings_get hooks.SessionStart.0.hooks.0.timeout)"
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

# Foreign handlers wrapped around ours, a drifted copy of ours in a second
# group, and a group that came in empty. Only python3 ever meets any of it.
write_hard_settings() {
  mkdir -p "${HOME}/.claude"
  cat >"$(settings_file)" <<'JSON'
{
  "model": "opus",
  "hooks": {
    "Stop": [{ "matcher": "", "hooks": [{ "type": "command", "command": "echo stop" }] }],
    "SessionStart": [
      { "matcher": "startup", "hooks": [
        { "type": "command", "command": "echo before" },
        { "type": "command", "command": "bash '/gone/lib/auto-update.sh' --json", "timeout": 45 },
        { "type": "command", "command": "echo after" }
      ] },
      { "matcher": "resume", "hooks": [] },
      { "matcher": "clear", "hooks": [
        { "type": "command", "command": "bash '/gone/lib/auto-update.sh' --json", "timeout": 10 }
      ] }
    ]
  }
}
JSON
}

# python3, node and jq are three implementations of one algorithm, so run the
# same file through each and compare what comes out.
case_settings_engines_agree() {
  detect_claude
  local registered removed

  write_hard_settings
  install_skills
  registered="$(cat "$(settings_file)")"
  assert_eq "one handler" "1" "$(hook_count)"
  assert_eq "raised timeout kept" "45" "$(settings_get hooks.SessionStart.0.hooks.1.timeout)"
  assert_contains "foreign before kept" "$registered" "echo before"
  assert_contains "foreign after kept" "$registered" "echo after"
  assert_contains "Stop kept" "$registered" "echo stop"
  assert_eq "empty group kept, ours-only group dropped" "2" "$(group_count)"
  install_skills --no-auto-update
  removed="$(cat "$(settings_file)")"
  assert_eq "python3 removed ours" "0" "$(hook_count)"

  if [ -n "$REAL_NODE" ]; then
    ln -sf "$REAL_NODE" "${CASE_ROOT}/bin/node"
    broken_shim python3
    # jq has to go too, or a dead node just falls through to it and every
    # assertion below still passes.
    broken_shim jq
    write_hard_settings
    install_skills --auto-update
    assert_eq "node register" "$registered" "$(cat "$(settings_file)")"
    install_skills --no-auto-update
    assert_eq "node remove" "$removed" "$(cat "$(settings_file)")"
    broken_shim node
    "$REAL_NODE" -v >/dev/null 2>&1 || fail "the node shim clobbered $REAL_NODE"
  else
    echo "    (no node available, skipping the node leg)"
    broken_shim python3
    broken_shim node
  fi

  if [ -n "$REAL_JQ" ]; then
    ln -sf "$REAL_JQ" "${CASE_ROOT}/bin/jq"
    write_hard_settings
    install_skills --auto-update
    assert_eq "jq register" "$registered" "$(cat "$(settings_file)")"
    install_skills --no-auto-update
    assert_eq "jq remove" "$removed" "$(cat "$(settings_file)")"
  else
    echo "    (no jq available, skipping the jq leg)"
  fi
}

case_settings_unparsable() {
  detect_claude
  mkdir -p "${HOME}/.claude"
  printf '{ nope' >"$(settings_file)"
  install_skills
  assert_contains "installer output" "$OUT" "cannot work with the JSON in"
  assert_contains "installer output" "$OUT" "hooks.SessionStart"
  assert_eq "file untouched" '{ nope' "$(cat "$(settings_file)")"
}

case_settings_write_fails() {
  detect_claude
  local body foreign
  body="$(cat <<'SH'
#!/bin/sh
# Only the settings write must fail; the invocations record needs a real mv.
for last; do :; done
case "$last" in
  */settings.json) exit 1 ;;
esac
exec /bin/mv "$@"
SH
)"
  write_shim mv "$body"
  install_skills
  assert_contains "installer output" "$OUT" "could not write to"
  assert_contains "installer output" "$OUT" "hooks.SessionStart"
  assert_not_contains "installer output" "$OUT" "Registered a daily"
  assert_file_missing "$(settings_file)"
  rm -f "${CASE_ROOT}/bin/mv"

  foreign='{ "model": "opus" }'
  printf '%s\n' "$foreign" >"$(settings_file)"
  chmod 500 "${HOME}/.claude"
  install_skills
  assert_contains "installer output" "$OUT" "could not write to"
  assert_contains "installer output" "$OUT" "hooks.SessionStart"
  assert_not_contains "installer output" "$OUT" "Registered a daily"
  chmod 700 "${HOME}/.claude"
  assert_eq "file untouched" "$foreign" "$(cat "$(settings_file)")"

  install_skills
  assert_eq "one handler" "1" "$(hook_count)"
  chmod 500 "${HOME}/.claude"
  install_skills --no-auto-update
  assert_contains "installer output" "$OUT" "could not write to"
  assert_contains "installer output" "$OUT" "by hand"
  chmod 700 "${HOME}/.claude"
  assert_eq "handler still there" "1" "$(hook_count)"

  # The previous leg's --no-auto-update left the opt-out marker set (${STATE}
  # sits outside the dir we just chmod-restricted, so that write succeeded);
  # clear it, or this plain install takes the opted-out branch instead of
  # exercising the write failure.
  rm -f "${STATE}/opt-out"
  rm -f "$(settings_file)"
  chmod 500 "${HOME}/.claude"
  install_skills
  chmod 700 "${HOME}/.claude"
  assert_contains "installer output" "$OUT" "could not write to"
  assert_contains "installer output" "$OUT" "hooks.SessionStart"
  assert_not_contains "installer output" "$OUT" "no working python3"
  assert_not_contains "installer output" "$OUT" "Registered a daily"
  assert_file_missing "$(settings_file)"
}

# Both shapes, through whichever engine is live: a key that is present and null
# is not an absent key, and overwriting it would throw away what the user wrote.
assert_null_hooks_refused() {
  local doc
  for doc in '{"hooks": null}' '{"hooks": {"SessionStart": null}}'; do
    printf '%s\n' "$doc" >"$(settings_file)"
    install_skills
    assert_contains "$1 refused it" "$OUT" "cannot work with the JSON in"
    assert_eq "$1 left the file alone" "$doc" "$(cat "$(settings_file)")"
  done
}

case_settings_null_hooks() {
  detect_claude
  mkdir -p "${HOME}/.claude"
  assert_null_hooks_refused python3

  if [ -n "$REAL_NODE" ]; then
    ln -sf "$REAL_NODE" "${CASE_ROOT}/bin/node"
    broken_shim python3
    broken_shim jq
    assert_null_hooks_refused node
    broken_shim node
    "$REAL_NODE" -v >/dev/null 2>&1 || fail "the node shim clobbered $REAL_NODE"
  else
    echo "    (no node available, skipping the node leg)"
    broken_shim python3
    broken_shim node
  fi

  if [ -n "$REAL_JQ" ]; then
    ln -sf "$REAL_JQ" "${CASE_ROOT}/bin/jq"
    assert_null_hooks_refused jq
  else
    echo "    (no jq available, skipping the jq leg)"
  fi
}

# Windows editors leave a BOM; Claude Code reads past it, so the engines must
# too, and drop it on the way out.
case_settings_with_bom() {
  detect_claude
  mkdir -p "${HOME}/.claude"
  local file
  file="$(settings_file)"
  printf '\357\273\277{ "model": "opus" }\n' >"$file"
  install_skills
  assert_eq "python3 registered" "1" "$(hook_count)"
  assert_eq "model kept" "opus" "$(settings_get model)"

  if [ -n "$REAL_NODE" ]; then
    ln -sf "$REAL_NODE" "${CASE_ROOT}/bin/node"
    broken_shim python3
    broken_shim jq
    printf '\357\273\277{ "model": "opus" }\n' >"$file"
    install_skills
    assert_eq "node registered" "1" "$(hook_count)"
    broken_shim node
    "$REAL_NODE" -v >/dev/null 2>&1 || fail "the node shim clobbered $REAL_NODE"
  else
    echo "    (no node available, skipping the node leg)"
    broken_shim python3
    broken_shim node
  fi

  if [ -n "$REAL_JQ" ]; then
    ln -sf "$REAL_JQ" "${CASE_ROOT}/bin/jq"
    printf '\357\273\277{ "model": "opus" }\n' >"$file"
    install_skills
    assert_eq "jq registered" "1" "$(hook_count)"
  else
    echo "    (no jq available, skipping the jq leg)"
  fi
}

# Removing what is not there is a no-op in every engine: a SessionStart list
# the user left empty is theirs, not a group we emptied.
case_remove_with_nothing_of_ours() {
  detect_claude
  mkdir -p "${HOME}/.claude"
  local file before rc
  file="$(settings_file)"
  before='{ "hooks": { "SessionStart": [] } }'
  printf '%s\n' "$before" >"$file"
  install_skills --no-auto-update
  assert_contains "installer output" "$OUT" "opted out"
  assert_eq "installer left the file alone" "$before" "$(cat "$file")"

  rc=0
  settings_merge_rc "$file" remove || rc=$?
  assert_eq "python3: nothing to do" "2" "$rc"
  assert_eq "python3: file untouched" "$before" "$(cat "$file")"

  if [ -n "$REAL_NODE" ]; then
    ln -sf "$REAL_NODE" "${CASE_ROOT}/bin/node"
    broken_shim python3
    broken_shim jq
    rc=0
    settings_merge_rc "$file" remove || rc=$?
    assert_eq "node: nothing to do" "2" "$rc"
    assert_eq "node: file untouched" "$before" "$(cat "$file")"
    broken_shim node
    "$REAL_NODE" -v >/dev/null 2>&1 || fail "the node shim clobbered $REAL_NODE"
  else
    echo "    (no node available, skipping the node leg)"
    broken_shim python3
    broken_shim node
  fi

  if [ -n "$REAL_JQ" ]; then
    ln -sf "$REAL_JQ" "${CASE_ROOT}/bin/jq"
    rc=0
    settings_merge_rc "$file" remove || rc=$?
    assert_eq "jq: nothing to do" "2" "$rc"
    assert_eq "jq: file untouched" "$before" "$(cat "$file")"
  else
    echo "    (no jq available, skipping the jq leg)"
  fi
}

case_interpreter_fallthrough() {
  detect_claude
  broken_shim python3
  if [ -n "$REAL_NODE" ]; then
    ln -sf "$REAL_NODE" "${CASE_ROOT}/bin/node"
    broken_shim jq
    install_skills
    assert_eq "node did the merge" "1" "$(hook_count)"
    rm -f "$(settings_file)"
    broken_shim node
    "$REAL_NODE" -v >/dev/null 2>&1 || fail "the node shim clobbered $REAL_NODE"
  else
    echo "    (no node available, skipping the node leg)"
  fi
  if [ -n "$REAL_JQ" ]; then
    ln -sf "$REAL_JQ" "${CASE_ROOT}/bin/jq"
    install_skills
    assert_eq "jq did the merge" "1" "$(hook_count)"
  else
    echo "    (no jq available, skipping the jq leg)"
  fi
}

# Every other remove test runs under python3. node and jq have to drop the
# handler and the emptied group too.
case_remove_interpreter_fallthrough() {
  detect_claude
  broken_shim python3
  if [ -n "$REAL_NODE" ]; then
    ln -sf "$REAL_NODE" "${CASE_ROOT}/bin/node"
    broken_shim jq
    install_skills
    assert_eq "node registered" "1" "$(hook_count)"
    install_skills --no-auto-update
    assert_eq "node removed" "0" "$(hook_count)"
    assert_eq "node dropped the group" "0" "$(group_count)"
    broken_shim node
    "$REAL_NODE" -v >/dev/null 2>&1 || fail "the node shim clobbered $REAL_NODE"
  else
    echo "    (no node available, skipping the node leg)"
  fi
  if [ -n "$REAL_JQ" ]; then
    ln -sf "$REAL_JQ" "${CASE_ROOT}/bin/jq"
    install_skills --auto-update
    assert_eq "jq registered" "1" "$(hook_count)"
    install_skills --no-auto-update
    assert_eq "jq removed" "0" "$(hook_count)"
    assert_eq "jq dropped the group" "0" "$(group_count)"
  else
    echo "    (no jq available, skipping the jq leg)"
  fi
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

case_term_ends_the_fetch() {
  detect_claude
  install_skills
  write_shim ssh "$(printf '#!/bin/sh\necho $$ > %s\nexec sleep 30' "${CASE_ROOT}/ssh.pid")"
  git -C "$CLONE" remote set-url origin ssh://localhost/nope.git
  make_due
  local pid child rc
  bash "${CLONE}/lib/auto-update.sh" --json >/dev/null &
  pid=$!
  sleep 2
  child="$(cat "${CASE_ROOT}/ssh.pid" 2>/dev/null)"
  kill -TERM "$pid" 2>/dev/null
  wait "$pid"
  rc=$?
  assert_eq "exit status after TERM" "0" "$rc"
  [ -d "${STATE}/lock" ] && fail "the lock should be released on TERM"
  if [ -z "$child" ]; then
    fail "the ssh shim never recorded a pid"
  elif kill -0 "$child" 2>/dev/null; then
    fail "the stalled transport survived the TERM"
    kill -9 "$child" 2>/dev/null
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
conflict_skips_replay
replay_failure
diverged
non_default_branch
other_name_tracking_default
detached
no_upstream
offline
offline_for_a_week
offline_url_redacted
fetch_hang
ssh_guard
throttled
lock_held
stale_lock
lock_not_ours
lock_takeover_loser
term_releases_the_lock
term_ends_the_fetch
state_in_worktree
state_in_submodule
copies_recorded
two_reasons
feedback_is_json_escaped
moved_clone
drifted_hook_entry
opt_out_and_back_in
opt_out_without_git
opt_out_from_other_target
marker_write_fails
rules_installer_registers
claude_not_detected
git_unusable
symlinked_clone_path
non_claude_skills_dir
no_upstream_at_install
detached_at_install
apostrophe_in_clone_path
snippet_json_escaped
apostrophe_in_replay_advice
settings_created
settings_keeps_foreign_hooks
settings_engines_agree
settings_unparsable
settings_write_fails
settings_null_hooks
settings_with_bom
remove_with_nothing_of_ours
interpreter_fallthrough
remove_interpreter_fallthrough
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

WANTED="$*"
KNOWN=" $(printf '%s' "$CASES" | tr '\n' ' ') "
for name in $WANTED; do
  case "$KNOWN" in
    *" ${name} "*) ;;
    *) die "unknown case: ${name}" ;;
  esac
done

python_usable || die "no usable python3 found; the harness reads settings.json and hook output with it"

mkdir -p "$RUNS"
export HOME="${RUNS}/_home"
mkdir -p "$HOME"
export PATH="$BASE_PATH"
build_template

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
