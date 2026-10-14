#!/usr/bin/env bash
#
# Checks a skill folder before it ships: every .md through compact-docs-writer's check-doc.sh,
# then the frontmatter rules — present and closed; `name` present, kebab-case and equal to the
# folder name; `description` present and free of `:`; `disable-model-invocation: true` paired
# with `type: flow`. Inside a git repo it also prints `metadata.version` at HEAD, at the merge
# base with the default branch and in the working tree, for the bump decision.
#
# Usage: check-skill.sh <skill-dir>
#   CHECK_SKILL_AS=<dir>  check a draft folder as if it were <dir> (the skill's real folder: name,
#                         links and git versions are judged there).
#   CHECK_DOC=<path>      check-doc.sh to use; default: ../../compact-docs-writer/scripts/check-doc.sh
#                         relative to this script.
# One line per failure, `file:line: message`; exit 1 when any was found, 2 on usage errors.

set -u

dir="${1:-}"
[ -n "$dir" ] && [ -d "$dir" ] || { echo "usage: check-skill.sh <skill-dir>" >&2; exit 2; }
dir="$(cd "$dir" && pwd -P)"
as="${CHECK_SKILL_AS:-$dir}"
[ -d "$as" ] && as="$(cd "$as" && pwd -P)"
skill="$dir/SKILL.md"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
check_doc="${CHECK_DOC:-$here/../../compact-docs-writer/scripts/check-doc.sh}"
[ -f "$check_doc" ] || {
  echo "check-skill: check-doc.sh not found at $check_doc (install compact-docs-writer beside this skill, or set CHECK_DOC)" >&2
  exit 2
}

fail=0
report() { printf '%s:%s: %s\n' "$skill" "$1" "$2"; fail=1; }

[ -f "$skill" ] || { echo "$skill:1: no SKILL.md in $dir"; exit 1; }

while IFS= read -r -d '' f; do
  CHECK_DOC_AS="$as/${f#"$dir"/}" bash "$check_doc" "$f" || fail=1
done < <(find "$dir" -name '*.md' -print0 | sort -z)

# Frontmatter: lines between the opening `---` on line 1 and the next `---`.
if [ "$(head -n 1 "$skill")" != "---" ]; then
  report 1 "no frontmatter (first line must be ---)"
  exit 1
fi
fm_end="$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$skill")"
[ -n "$fm_end" ] || { report 1 "frontmatter never closed"; exit 1; }
fm_line() { awk -v end="$fm_end" -v key="$1" 'NR > 1 && NR < end && index($0, key ":") == 1 { print NR; exit }' "$skill"; }
fm_value() {
  local n; n="$(fm_line "$1")"
  [ -n "$n" ] || return 0
  sed -n "${n}p" "$skill" | sed -e "s/^$1:[[:space:]]*//" -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

name="$(fm_value name)"
if [ -z "$name" ]; then
  report 2 "name missing"
else
  n="$(fm_line name)"
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || report "$n" "name is not kebab-case: $name"
  [ "$name" = "$(basename "$as")" ] || report "$n" "name '$name' differs from folder '$(basename "$as")'"
fi

desc="$(fm_value description)"
if [ -z "$desc" ]; then
  report 2 "description missing"
else
  case "$desc" in *:*) report "$(fm_line description)" "description contains ':'" ;; esac
fi

flag="$(fm_value disable-model-invocation)"
if [ "$flag" = "true" ] && [ "$(fm_value type)" != "flow" ]; then
  report "$(fm_line disable-model-invocation)" "disable-model-invocation: true without type: flow"
fi

# Version at HEAD, at the merge base with the default branch, and in the working tree.
version_of() { awk -v end="$fm_end" 'NR > 1 && NR < end && /^[[:space:]]+version:/ { v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); gsub(/"/, "", v); print v; exit }'; }
if [ -d "$as" ] && top="$(git -C "$as" rev-parse --show-toplevel 2>/dev/null)"; then
  rel="${as#"$top"/}/SKILL.md"
  base_ref="$(git -C "$as" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -z "$base_ref" ]; then
    for cand in origin/main origin/master main master; do
      git -C "$as" rev-parse -q --verify "$cand" >/dev/null 2>&1 && { base_ref="$cand"; break; }
    done
  fi
  v_head="$(git -C "$as" show "HEAD:$rel" 2>/dev/null | version_of)"
  v_base=""
  if [ -n "$base_ref" ]; then
    mb="$(git -C "$as" merge-base HEAD "$base_ref" 2>/dev/null || true)"
    [ -n "$mb" ] && v_base="$(git -C "$as" show "$mb:$rel" 2>/dev/null | version_of)"
  fi
  v_tree="$(version_of < "$skill")"
  echo "$skill: version HEAD=${v_head:-none} merge-base(${base_ref:-?})=${v_base:-none} working-tree=${v_tree:-none}"
fi

exit "$fail"
