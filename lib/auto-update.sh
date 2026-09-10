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
TOKEN=""
STAMP=""
OFFLINE=""
REASON=""
JSON=0
KEY=""
MESSAGE=""
CHILD=""

DAY=86400
HOUR=3600
OFFLINE_STUCK_AFTER=604800
FETCH_BUDGET=6
# The stamp keeps a second run out for an hour at the least, so a lock
# younger than that belongs to a run that started alongside this one, not to
# one that died.
LOCK_STALE_AFTER=3600

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
# Polled in tenths: a whole second per poll would cost more than the fetch
# itself on a good day.
watchdog() {
  local secs="$1"
  shift
  local pid ticks=0 rc
  "$@" >>"$LOG" 2>"$ERRF" &
  pid=$!
  CHILD="$pid"
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ticks" -ge "$((secs * 10))" ]; then
      # git leaves its transport (ssh, a credential helper) as a direct
      # child; killing git alone orphans it instead of ending the hang.
      pkill -P "$pid" 2>/dev/null
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      CHILD=""
      return 124
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done
  wait "$pid"
  rc=$?
  CHILD=""
  return "$rc"
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

# git remote get-url returns userinfo verbatim; git >= 2.50 already redacts it
# from its own transport errors, but this is belt and braces for older git.
redact_userinfo() {
  sed -E 's#([A-Za-z][A-Za-z0-9+.-]*://)[^/@[:space:]]*@#\1#g'
}

# git's first stderr line is generic ("merge failed"); the file names follow on
# the next ones, and they are what tells two conflicts apart.
stderr_detail() {
  head -5 "$ERRF" 2>/dev/null | awk '
    { sub(/^error: /, ""); sub(/^fatal: /, "");
      gsub(/[ \t]+/, " "); gsub(/^ +| +$/, "");
      if (length($0)) out = (out == "" ? $0 : out "; " $0) }
    END { print out }' | redact_userinfo
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

# The lock can change hands mid-run: a run that outlives LOCK_STALE_AFTER is
# taken over, and a run that lost the start-up race may only find out here.
still_owner() {
  [ "$(cat "${LOCK}/owner" 2>/dev/null)" = "$TOKEN" ]
}

# Only ours to remove: a run that took over after we were declared stale owns
# the directory now, and deleting it would let a third run in.
release_lock() {
  still_owner || return 0
  rm -rf "$LOCK"
}

# End the in-flight fetch's whole tree on a signal, or it and its ssh or
# credential-helper children keep running after this shell exits.
kill_child() {
  [ -n "$CHILD" ] || return 0
  pkill -P "$CHILD" 2>/dev/null
  kill "$CHILD" 2>/dev/null
  wait "$CHILD" 2>/dev/null
  CHILD=""
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

  local held takeover=0
  if ! mkdir "$LOCK" 2>/dev/null; then
    held=0
    [ -f "${LOCK}/ts" ] && held="$(cat "${LOCK}/ts" 2>/dev/null)"
    case "$held" in ''|*[!0-9]*) held=0 ;; esac
    [ "$((now - held))" -lt "$LOCK_STALE_AFTER" ] && finish_silent
    takeover=1
  fi
  # Stamp it before anything else: a lock with no ts reads as stale, and a run
  # starting right now would take it over.
  printf '%s\n' "$now" >"${LOCK}/ts" 2>/dev/null
  TOKEN="$$:${now}"
  printf '%s\n' "$TOKEN" >"${LOCK}/owner" 2>/dev/null
  # Whoever's token survives owns the lock; the other abandons the run. Two
  # runs that judge the same lock stale both write their own token into it,
  # so nothing is renamed, deleted or replaced, and there is no marker a
  # killed run could leave behind to wedge a later takeover.
  [ "$takeover" -eq 1 ] && sleep 1
  still_owner || finish_silent
  trap release_lock EXIT
  # exit here, or bash resumes the run once the handler returns
  trap 'kill_child; exit 0' TERM INT HUP

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
    url="$(printf '%s\n' "$url" | redact_userinfo)"
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
      "agent-toolkit is not updating while ${CLONE} is on ${branch}, which does not track ${remote}/${default}; it resumes after git -C '${CLONE}' checkout ${default}."
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
    still_owner || finish_silent
    git -C "$CLONE" merge --ff-only '@{u}' >>"$LOG" 2>"$ERRF"
    rc=$?
    cat "$ERRF" >>"$LOG" 2>/dev/null
    if [ "$rc" -ne 0 ]; then
      detail="$(stderr_detail)"
      add_outcome "error:merge:${branch}:${detail}" \
        "agent-toolkit could not update ${CLONE}: ${detail}"
      report_and_exit
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
    case "${CLONE}${agents_dir}${target}" in
      *\'*) cmd="${script} for ${target}; its path has an apostrophe, so the command cannot be safely quoted here" ;;
      *) cmd="bash '${CLONE}/${script}' --agents-dir '${agents_dir}' ${flag} '${target}'" ;;
    esac
    still_owner || finish_silent
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
    case "${CLONE}${agents_dir}${target}" in
      *\'*) cmd="${script} for ${target} with --force; its path has an apostrophe, so the command cannot be safely quoted here" ;;
      *) cmd="bash '${CLONE}/${script}' --agents-dir '${agents_dir}' ${flag} '${target}' --force" ;;
    esac
    add_outcome "copies:${script}:${target}:${head_now}" \
      "agent-toolkit updated ${CLONE}, but ${target} holds copies rather than links, so it did not follow. Re-run: ${cmd}"
  done

  report_and_exit
}

main "$@"
