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
# fixtures/.editorconfig sets 99, the repo root 100. `as-draft-added` adds a linked file only the
# draft holds. The `crlf-*` cases are runtime CRLF copies of a fixture (no CRLF bytes are
# committed), checked as the LF original. `version-shrunk` commits a skill in a throwaway repo
# under runs/, then drops frontmatter lines in the working tree, so HEAD's version sits past the
# draft's closing `---`; `version-root` does the same with the skill folder as the repo root;
# `version-crlf` commits the skill with CRLF line endings. The `base-*` cases build throwaway
# repos whose refs exercise the base-ref resolution of the version line. The `desc-*` fixtures
# hold multi-line descriptions (folded, literal, plain, quoted, next-line).
# Output lands in runs/<timestamp>/<case>.log.
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
md-off|0|
double-backtick|0|
as-draft-added|0|
crlf-clean|0|
crlf-long-frontmatter|0|
crlf-long-line|1|crlf-long-line/SKILL.md:11: line is 100 characters, max 99
desc-folded|1|desc-folded/SKILL.md:5: description contains
desc-literal|1|desc-literal/SKILL.md:5: description contains
desc-plain|1|desc-plain/SKILL.md:4: description contains
desc-dquote|1|desc-dquote/SKILL.md:4: description contains
desc-next-line|0|
desc-multiline-clean|0|
version-shrunk|0|version HEAD=1.0 merge-base(main)=1.0 working-tree=1.1
version-root|0|version HEAD=1.0 merge-base(main)=1.0 working-tree=1.1
version-crlf|0|version HEAD=1.0 merge-base(main)=1.0 working-tree=1.1
base-origin-head|0|merge-base(origin/main)=1.0
base-origin-head-dangling|0|merge-base(origin/master)=1.0
base-develop|0|merge-base(origin/develop)=1.0
base-unknown|0|merge-base(none)=base unknown
base-override|0|merge-base(trunk)=1.0
base-new-skill|0|version HEAD=1.0 merge-base(main)=absent at base working-tree=1.0
base-unrelated|0|merge-base(main)=no merge base
'

# $1 source fixture, $2 destination: a copy whose .md files end every line with CRLF
crlf_copy() {
  local f
  cp -R "$1" "$2" || return 1
  while IFS= read -r -d '' f; do
    awk '{ printf "%s\r\n", $0 }' "$f" >"$f.tmp" && mv "$f.tmp" "$f" || return 1
  done < <(find "$2" -name '*.md' -print0)
}

# $1 repo dir, $2 default branch. A failed init must never walk up into this toolkit's repo:
# the ceiling stops discovery below runs/, and the toplevel check aborts the case.
new_repo() {
  export GIT_CEILING_DIRECTORIES="$RUNS"
  mkdir -p "$1" || return 1
  git -C "$1" -c "init.defaultBranch=$2" init -q --template= || return 1
  [ "$(git -C "$1" rev-parse --show-toplevel)" = "$(cd "$1" && pwd -P)" ] || return 1
}

# $1 repo dir
commit_all() {
  git -C "$1" -c core.autocrlf=false -c core.safecrlf=false add -A &&
    git -C "$1" -c core.autocrlf=false -c core.safecrlf=false -c user.name=t -c user.email=t@t commit -qm commit
}

# $1 skill dir, $2 name, $3 version, $4 line ending (default LF)
write_skill() {
  local nl="${4:-\n}"
  mkdir -p "$1" || return 1
  printf -- "---${nl}name: %s${nl}description: A fixture skill.${nl}license: MIT${nl}type: flow${nl}metadata:${nl}  version: \"%s\"${nl}---${nl}${nl}# Fixture${nl}" "$2" "$3" >"$1/SKILL.md"
}

# $1 case name, $2 repo dir, $3 skill dir, $4 line ending (default LF)
version_case() {
  local name="$1" repo="$2" skill="$3" nl="${4:-\n}"
  new_repo "$repo" main || return 1
  write_skill "$skill" "$name" 1.0 "$nl" || return 1
  commit_all "$repo" || return 1
  printf -- "---${nl}name: %s${nl}description: A fixture skill.${nl}metadata:${nl}  version: \"1.1\"${nl}---${nl}${nl}# Fixture${nl}" "$name" >"$skill/SKILL.md"
  bash "$CHECK_SKILL" "$skill"
}

# $1 case name, $2 default branch, $3 shell snippet run inside the repo before the check,
# $4 `placeholder` to commit only a placeholder file first (the snippet then adds the skill)
base_case() {
  local name="$1" branch="$2" setup="$3" repo="$RUNS/$1"
  new_repo "$repo" "$branch" || return 1
  if [ "${4:-}" = placeholder ]; then printf 'placeholder\n' >"$repo/README.md"; else write_skill "$repo/$name" "$name" 1.0 || return 1; fi
  commit_all "$repo" || return 1
  (cd "$repo" && eval "$setup") || return 1
  bash "$CHECK_SKILL" "$repo/$name"
}

failed=0
run_case() {
  local name="$1" want_exit="$2" want_lines="$3" log="$RUNS/$1.log" got_exit line ok=1
  case "$name" in
    as-draft)
      cp -R "$FIXTURES/clean" "$RUNS/draft-copy"
      CHECK_SKILL_AS="$FIXTURES/clean" bash "$CHECK_SKILL" "$RUNS/draft-copy" >"$log" 2>&1 ;;
    as-draft-new)
      cp -R "$FIXTURES/clean" "$RUNS/draft-new"
      CHECK_SKILL_AS="$FIXTURES/not-created-yet/clean" bash "$CHECK_SKILL" "$RUNS/draft-new" >"$log" 2>&1 ;;
    as-draft-new-cfg)
      cp -R "$FIXTURES/long-line" "$RUNS/draft-new-cfg"
      CHECK_SKILL_AS="$FIXTURES/not-created-yet/long-line" bash "$CHECK_SKILL" "$RUNS/draft-new-cfg" >"$log" 2>&1 ;;
    as-draft-added)
      cp -R "$FIXTURES/clean" "$RUNS/draft-added"
      printf '# Added\n' >"$RUNS/draft-added/added.md"
      printf '\nSee [added.md](added.md).\n' >>"$RUNS/draft-added/SKILL.md"
      CHECK_SKILL_AS="$FIXTURES/clean" bash "$CHECK_SKILL" "$RUNS/draft-added" >"$log" 2>&1 ;;
    crlf-clean)
      crlf_copy "$FIXTURES/clean" "$RUNS/$name"
      printf '%s\r\n' "$(head -c 99 /dev/zero | tr '\0' a)" >>"$RUNS/$name/SKILL.md"
      CHECK_SKILL_AS="$FIXTURES/clean" bash "$CHECK_SKILL" "$RUNS/$name" >"$log" 2>&1 ;;
    crlf-long-frontmatter)
      cp -R "$FIXTURES/clean" "$RUNS/$name-lf"
      awk '/^description:/ { print "description: A fixture skill whose description runs on past the line limit of the fixtures to prove frontmatter is never measured."; next } { print }' "$FIXTURES/clean/SKILL.md" >"$RUNS/$name-lf/SKILL.md"
      crlf_copy "$RUNS/$name-lf" "$RUNS/$name"
      CHECK_SKILL_AS="$FIXTURES/clean" bash "$CHECK_SKILL" "$RUNS/$name" >"$log" 2>&1 ;;
    crlf-long-line)
      crlf_copy "$FIXTURES/long-line" "$RUNS/$name"
      CHECK_SKILL_AS="$FIXTURES/long-line" bash "$CHECK_SKILL" "$RUNS/$name" >"$log" 2>&1 ;;
    version-shrunk) version_case "$name" "$RUNS/version-repo" "$RUNS/version-repo/$name" >"$log" 2>&1 ;;
    version-root) version_case "$name" "$RUNS/$name" "$RUNS/$name" >"$log" 2>&1 ;;
    version-crlf) version_case "$name" "$RUNS/$name" "$RUNS/$name/$name" '\r\n' >"$log" 2>&1 ;;
    base-origin-head)
      base_case "$name" main 'git update-ref refs/remotes/origin/main HEAD && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main' >"$log" 2>&1 ;;
    base-origin-head-dangling)
      base_case "$name" master 'git update-ref refs/remotes/origin/master HEAD && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main' >"$log" 2>&1 ;;
    base-develop) base_case "$name" develop 'git update-ref refs/remotes/origin/develop HEAD' >"$log" 2>&1 ;;
    base-unknown) base_case "$name" trunk '' >"$log" 2>&1 ;;
    base-override) CHECK_SKILL_BASE=trunk base_case "$name" trunk '' >"$log" 2>&1 ;;
    base-new-skill)
      base_case "$name" main 'git checkout -q -b feature && write_skill "$PWD/'"$name"'" '"$name"' 1.0 && commit_all "$PWD"' placeholder >"$log" 2>&1 ;;
    base-unrelated) base_case "$name" main 'git checkout -q --orphan other && git -c user.name=t -c user.email=t@t commit -qm orphan' >"$log" 2>&1 ;;
    *) bash "$CHECK_SKILL" "$FIXTURES/$name" >"$log" 2>&1 ;;
  esac
  got_exit=$?
  [ "$got_exit" -eq "$want_exit" ] || { echo "  exit $got_exit, want $want_exit"; ok=0; }
  if grep -q $'\r' "$log"; then echo "  carriage return in output"; ok=0; fi
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
