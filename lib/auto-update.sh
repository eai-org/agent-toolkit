#!/usr/bin/env bash
#
# Keep this clone current: once a day, fast-forward it to its upstream and
# replay the installer runs it has recorded, so the installed skills and rules
# follow the repo.
#
# Two output modes, both silent unless the clone is stuck or something failed:
#
#   --json   one JSON object on stdout, {} or {"systemMessage": "..."}, for
#            hooks that parse what their handler prints;
#   (none)   the message as plain lines, for cron or a hook that logs it.
#
# Exits 0 on every path. Git and installer output goes to the log in the state
# dir, never to stdout. The installers wire this up; the details, and the
# recipes for agents whose hooks the installers do not know, are in
# docs/auto-update.md.

set -u

CLONE=""
STATE=""
INV=""
LOG=""
ERRF=""
LOCK=""
STAMP=""
OFFLINE=""
REASON=""
JSON=0
KEY=""
MESSAGE=""

DAY=86400
HOUR=3600
OFFLINE_STUCK_AFTER=604800
FETCH_BUDGET=6
LOCK_STALE_AFTER=60

# Collect what this run has to say. Several outcomes can pile up: the keys
# decide whether it is worth saying again, the lines are what the user reads.
add_outcome() {
  if [ -z "$KEY" ]; then
    KEY="$1"
  else
    KEY="${KEY}|$1"
  fi
  if [ -z "$MESSAGE" ]; then
    MESSAGE="$2"
  else
    MESSAGE="${MESSAGE}
$2"
  fi
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037'
}

# Nothing to say, and nothing worth remembering either: a throttled, locked or
# offline run must leave an earlier reason standing.
finish_silent() {
  [ "$JSON" -eq 1 ] && printf '{}\n'
  exit 0
}

# Say it once per problem. The reason file holds the keys of the last run that
# got as far as the fetch, so a problem that is fixed and comes back is worth
# saying again.
report_and_exit() {
  local prev=""
  [ -f "$REASON" ] && prev="$(cat "$REASON" 2>/dev/null)"
  printf '%s\n' "$KEY" >"$REASON" 2>/dev/null

  if [ -n "$KEY" ] && [ "$KEY" != "$prev" ]; then
    if [ "$JSON" -eq 1 ]; then
      printf '{"systemMessage": "%s"}\n' "$(json_escape "$MESSAGE")"
    else
      printf '%s\n' "$MESSAGE"
    fi
    exit 0
  fi
  finish_silent
}

# Bounded run: no timeout(1) to lean on, and a fetch that hangs would burn the
# whole hook budget. stdout to the log, stderr kept apart so we can quote it.
watchdog() {
  local secs="$1"
  shift
  local pid i=0
  "$@" >>"$LOG" 2>"$ERRF" &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge "$secs" ]; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 1
    i=$((i + 1))
  done
  wait "$pid"
}

# Nothing here may block on a prompt: no terminal is attached and the agent
# would sit on it until the hook times out.
guard_prompts() {
  export GIT_TERMINAL_PROMPT=0
  export GIT_ASKPASS=true
  export GCM_INTERACTIVE=never
  export SSH_ASKPASS_REQUIRE=never

  local cmd first
  cmd="${GIT_SSH_COMMAND:-}"
  [ -n "$cmd" ] || cmd="$(git -C "$CLONE" config core.sshCommand 2>/dev/null)"
  if [ -z "$cmd" ]; then
    # GIT_SSH is next in git's precedence, and exporting GIT_SSH_COMMAND would
    # override it. Leave whatever it points at alone.
    [ -n "${GIT_SSH:-}" ] && return 0
    cmd=ssh
  fi
  first="$(basename "${cmd%% *}")"
  case "$first" in
    ssh|ssh.exe) export GIT_SSH_COMMAND="$cmd -o BatchMode=yes -o ConnectTimeout=5" ;;
  esac
  return 0
}

# git's first stderr line is generic ("merge failed"); the file names follow on
# the next ones, and they are what tells two conflicts apart.
stderr_detail() {
  head -5 "$ERRF" 2>/dev/null | awk '
    { sub(/^error: /, ""); sub(/^fatal: /, "");
      gsub(/[ \t]+/, " "); gsub(/^ +| +$/, "");
      if (length($0)) out = (out == "" ? $0 : out "; " $0) }
    END { print out }'
}

# A recorded target the user has deleted stays deleted: the installer would
# recreate the whole tree in a place they cleared out.
prune_invocations() {
  local tmp="${STATE}/invocations.$$" changed=0 line
  local script agents_dir flag target rec_head copies

  [ -f "$INV" ] || return 0
  : >"$tmp" 2>/dev/null || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    IFS=$'\t' read -r script agents_dir flag target rec_head copies <<<"$line"
    if [ ! -d "$target" ] || [ ! -d "$agents_dir" ]; then
      changed=1
      continue
    fi
    printf '%s\n' "$line" >>"$tmp"
  done <"$INV"

  if [ "$changed" -eq 1 ]; then
    mv -f "$tmp" "$INV"
  else
    rm -f "$tmp"
  fi
  return 0
}

copies_flag() {
  local script="$1" target="$2" value
  value="$(awk -F '\t' -v s="$script" -v t="$target" \
    '$1 == s && $4 == t { c = $6 } END { print c }' "$INV" 2>/dev/null)"
  [ -n "$value" ] || value=0
  printf '%s' "$value"
}

main() {
  case "${1:-}" in
    --json) JSON=1 ;;
  esac

  CLONE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || finish_silent

  local git_dir
  git_dir="$(git -C "$CLONE" rev-parse --absolute-git-dir 2>/dev/null)" || finish_silent
  [ -n "$git_dir" ] || finish_silent
  STATE="${git_dir}/agent-toolkit"
  mkdir -p "$STATE" 2>/dev/null || finish_silent

  INV="${STATE}/invocations"
  LOG="${STATE}/log"
  ERRF="${STATE}/stderr"
  LOCK="${STATE}/lock"
  STAMP="${STATE}/stamp"
  OFFLINE="${STATE}/offline-since"
  REASON="${STATE}/reason"

  [ -e "${STATE}/opt-out" ] && finish_silent

  local now due
  now="$(date +%s 2>/dev/null)" || finish_silent
  due=0
  [ -f "$STAMP" ] && due="$(cat "$STAMP" 2>/dev/null)"
  case "$due" in ''|*[!0-9]*) due=0 ;; esac
  [ "$now" -lt "$due" ] && finish_silent
  # Marked done before doing anything: a run that dies must not come back every
  # session.
  printf '%s\n' "$((now + DAY))" >"$STAMP" 2>/dev/null

  local held
  if ! mkdir "$LOCK" 2>/dev/null; then
    held=0
    [ -f "${LOCK}/ts" ] && held="$(cat "${LOCK}/ts" 2>/dev/null)"
    case "$held" in ''|*[!0-9]*) held=0 ;; esac
    [ "$((now - held))" -lt "$LOCK_STALE_AFTER" ] && finish_silent
    # Whoever held it was killed mid-run, most likely by a hook timeout.
    rm -rf "$LOCK"
    mkdir "$LOCK" 2>/dev/null || finish_silent
  fi
  trap 'rm -rf "$LOCK"' EXIT TERM INT HUP
  printf '%s\n' "$now" >"${LOCK}/ts" 2>/dev/null

  : >"$LOG" 2>/dev/null
  : >"$ERRF" 2>/dev/null

  guard_prompts

  local branch remote
  branch="$(git -C "$CLONE" symbolic-ref --short -q HEAD 2>/dev/null)" || branch=""
  remote=""
  [ -n "$branch" ] && remote="$(git -C "$CLONE" config "branch.${branch}.remote" 2>/dev/null)"
  [ -n "$remote" ] || remote=origin

  if ! watchdog "$FETCH_BUDGET" git -C "$CLONE" fetch -q; then
    cat "$ERRF" >>"$LOG" 2>/dev/null
    printf '%s\n' "$((now + HOUR))" >"$STAMP" 2>/dev/null

    local since url last
    since=""
    [ -f "$OFFLINE" ] && since="$(cat "$OFFLINE" 2>/dev/null)"
    case "$since" in ''|*[!0-9]*) since="" ;; esac
    if [ -z "$since" ]; then
      printf '%s\n' "$now" >"$OFFLINE" 2>/dev/null
      finish_silent
    fi
    [ "$((now - since))" -lt "$OFFLINE_STUCK_AFTER" ] && finish_silent

    url="$(git -C "$CLONE" remote get-url "$remote" 2>/dev/null)" || url="$remote"
    last="$(stderr_detail)"
    [ -n "$last" ] && last=" ${last}."
    add_outcome "stuck:offline:${url}" \
      "agent-toolkit has not reached ${url} for a week, so ${CLONE} is not updating.${last} Check your network, or your access to that remote."
    report_and_exit
  fi
  rm -f "$OFFLINE"

  local dirty upstream default_ref default
  dirty="$(git -C "$CLONE" status --porcelain --untracked-files=no 2>/dev/null)"

  default_ref="$(git -C "$CLONE" symbolic-ref -q "refs/remotes/${remote}/HEAD" 2>/dev/null)"
  if [ -z "$default_ref" ] \
    && git -C "$CLONE" rev-parse --verify -q "refs/remotes/${remote}/main" >/dev/null 2>&1; then
    default_ref="refs/remotes/${remote}/main"
  fi
  default="${default_ref#refs/remotes/${remote}/}"
  [ -n "$default" ] || default=main

  upstream="$(git -C "$CLONE" rev-parse --symbolic-full-name '@{u}' 2>/dev/null)" || upstream=""

  if [ -n "$dirty" ]; then
    add_outcome "stuck:dirty:${branch}" \
      "agent-toolkit is not updating: ${CLONE} has uncommitted changes. Commit or stash them."
    report_and_exit
  fi
  if [ -z "$branch" ]; then
    add_outcome "stuck:detached:" \
      "agent-toolkit is not updating: ${CLONE} is on a detached HEAD. Run: git -C '${CLONE}' checkout ${default}"
    report_and_exit
  fi
  if [ -z "$upstream" ]; then
    add_outcome "stuck:no-upstream:${branch}" \
      "agent-toolkit is not updating: branch ${branch} in ${CLONE} has no upstream. Run: git -C '${CLONE}' branch --set-upstream-to ${remote}/${default}"
    report_and_exit
  fi
  # Any local branch name is fine as long as it follows the default branch;
  # a feature branch is someone's own work and not ours to fast-forward.
  if [ -n "$default_ref" ] && [ "$upstream" != "$default_ref" ]; then
    add_outcome "stuck:not-default:${branch}" \
      "agent-toolkit is not updating: ${CLONE} is on ${branch}, which does not track ${remote}/${default}. Run: git -C '${CLONE}' checkout ${default}"
    report_and_exit
  fi
  if ! git -C "$CLONE" merge-base --is-ancestor HEAD "$upstream" >/dev/null 2>&1; then
    add_outcome "stuck:diverged:${branch}" \
      "agent-toolkit is not updating: ${CLONE} has commits that are not on ${remote}/${default}. Push them or drop them; git -C '${CLONE}' log @{u}.. lists them."
    report_and_exit
  fi

  local head_before head_now rc detail
  head_before="$(git -C "$CLONE" rev-parse HEAD 2>/dev/null)"
  if [ "$head_before" != "$(git -C "$CLONE" rev-parse "$upstream" 2>/dev/null)" ]; then
    git -C "$CLONE" merge --ff-only '@{u}' >>"$LOG" 2>"$ERRF"
    rc=$?
    cat "$ERRF" >>"$LOG" 2>/dev/null
    if [ "$rc" -ne 0 ]; then
      detail="$(stderr_detail)"
      add_outcome "error:merge:${branch}:${detail}" \
        "agent-toolkit could not update ${CLONE}: ${detail}"
    fi
  fi

  prune_invocations

  local -a lines=()
  local -a replayed=()
  local line script agents_dir flag target rec_head copies cmd
  if [ -f "$INV" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] && lines+=("$line")
    done <"$INV"
  fi

  head_now="$(git -C "$CLONE" rev-parse HEAD 2>/dev/null)" || head_now=""

  # The list is a snapshot: each installer we run rewrites this file to stamp
  # its own line.
  for line in ${lines[@]+"${lines[@]}"}; do
    IFS=$'\t' read -r script agents_dir flag target rec_head copies <<<"$line"
    [ -n "$script" ] || continue
    [ "$rec_head" = "$head_now" ] && continue
    cmd="bash '${CLONE}/${script}' --agents-dir '${agents_dir}' ${flag} '${target}'"
    bash "${CLONE}/${script}" --agents-dir "$agents_dir" "$flag" "$target" >>"$LOG" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
      add_outcome "error:replay:${script}:${target}" \
        "agent-toolkit updated ${CLONE} but ${script} failed afterwards, so ${target} is out of date. Run it by hand: ${cmd}"
      continue
    fi
    replayed+=("$line")
  done

  for line in ${replayed[@]+"${replayed[@]}"}; do
    IFS=$'\t' read -r script agents_dir flag target rec_head copies <<<"$line"
    [ "$(copies_flag "$script" "$target")" = "1" ] || continue
    cmd="bash '${CLONE}/${script}' --agents-dir '${agents_dir}' ${flag} '${target}' --force"
    add_outcome "copies:${script}:${target}:${head_now}" \
      "agent-toolkit updated ${CLONE}, but ${target} holds copies rather than links, so it did not follow. Re-run: ${cmd}"
  done

  report_and_exit
}

main "$@"
