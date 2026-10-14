#!/usr/bin/env bash
#
# Harness for skills/compact-skill-creator/scripts/check-skill.sh and the check-doc.sh it runs.
#
# Usage:
#   bash test/compact-skill-creator/run.sh [case ...]
#
# Every case is a fixture skill under fixtures/<case>/; its expected exit code and the failure
# lines the output must carry are listed in CASES below. The `as-draft` case copies the clean
# fixture under another name and checks it with CHECK_SKILL_AS pointing at the original;
# `as-draft-new` and `as-draft-new-cfg` point CHECK_SKILL_AS at a folder that does not exist yet
# (create mode), the latter proving the .editorconfig walk starts from that folder:
# fixtures/.editorconfig sets 99, the repo root 100. Output lands in runs/<timestamp>/<case>.log.
# Exits non-zero if any case failed.

set -u

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${HARNESS_DIR}/../.." && pwd -P)"
CHECK_SKILL="${REPO_ROOT}/skills/compact-skill-creator/scripts/check-skill.sh"
FIXTURES="${HARNESS_DIR}/fixtures"
RUNS="${HARNESS_DIR}/runs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUNS"

# case|expected exit|required output lines, `;`-separated, each matched as a substring
CASES='
clean|0|
colon-in-description|1|colon-in-description/SKILL.md:3: description contains
flag-without-flow|1|flag-without-flow/SKILL.md:4: disable-model-invocation: true without type: flow
name-mismatch|1|name-mismatch/SKILL.md:2: name '"'"'other-name'"'"' differs from folder '"'"'name-mismatch'"'"'
long-line|1|long-line/SKILL.md:11: line is 100 characters, max 99
dangling-link|1|dangling-link/SKILL.md:11: dangling link: references/missing.md
no-frontmatter|1|no-frontmatter/SKILL.md:1: no frontmatter
as-draft|0|
as-draft-new|0|
as-draft-new-cfg|1|draft-new-cfg/SKILL.md:11: line is 100 characters, max 99
brace-list|1|brace-list/SKILL.md:11: line is 70 characters, max 60
'

failed=0
run_case() {
  local name="$1" want_exit="$2" want_lines="$3" log="$RUNS/$1.log" got_exit line ok=1
  if [ "$name" = "as-draft" ]; then
    cp -R "$FIXTURES/clean" "$RUNS/draft-copy"
    CHECK_SKILL_AS="$FIXTURES/clean" bash "$CHECK_SKILL" "$RUNS/draft-copy" >"$log" 2>&1
  elif [ "$name" = "as-draft-new" ]; then
    cp -R "$FIXTURES/clean" "$RUNS/draft-new"
    CHECK_SKILL_AS="$FIXTURES/not-created-yet/clean" bash "$CHECK_SKILL" "$RUNS/draft-new" >"$log" 2>&1
  elif [ "$name" = "as-draft-new-cfg" ]; then
    cp -R "$FIXTURES/long-line" "$RUNS/draft-new-cfg"
    CHECK_SKILL_AS="$FIXTURES/not-created-yet/long-line" bash "$CHECK_SKILL" "$RUNS/draft-new-cfg" >"$log" 2>&1
  else
    bash "$CHECK_SKILL" "$FIXTURES/$name" >"$log" 2>&1
  fi
  got_exit=$?
  [ "$got_exit" -eq "$want_exit" ] || { echo "  exit $got_exit, want $want_exit"; ok=0; }
  if [ "$want_exit" -eq 0 ] && grep -v ': version ' "$log" | grep -q .; then
    echo "  unexpected output:"; grep -v ': version ' "$log" | sed 's/^/    /'; ok=0
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    grep -qF -- "$line" "$log" || { echo "  missing line: $line"; ok=0; }
  done <<< "${want_lines//;/$'\n'}"
  if [ "$ok" -eq 1 ]; then echo "PASS $name"; else echo "FAIL $name (see $log)"; failed=1; fi
}

selected=("$@")
while IFS='|' read -r name want_exit want_lines; do
  [ -n "$name" ] || continue
  if [ ${#selected[@]} -gt 0 ]; then
    case " ${selected[*]} " in *" $name "*) ;; *) continue ;; esac
  fi
  run_case "$name" "$want_exit" "$want_lines"
done <<< "$CASES"

exit "$failed"
