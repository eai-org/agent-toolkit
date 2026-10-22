#!/usr/bin/env bash
#
# Checks a skill folder before it ships: every .md through compact-docs-writer's check-doc.sh,
# then the frontmatter rules — present and closed; `name` present, kebab-case and equal to the
# folder name; `description` present and free of `:`; `disable-model-invocation: true` paired
# with `type: flow`. A CRLF file is judged as its LF form. Inside a git repo it also prints
# `metadata.version` at HEAD, at the merge base with the base ref and in the working tree, for the
# bump decision. The base ref is resolved offline: CHECK_SKILL_BASE, else the remote HEAD of
# `upstream` then `origin` when its target exists, else the sole name among main, master, develop,
# development that exists as upstream/<n>, origin/<n> or a local branch. The line names the ref it
# used; `base unknown` means none qualified (set CHECK_SKILL_BASE), `absent at base` that the
# skill is new on the branch. The line never changes the exit code.
#
# Usage: check-skill.sh <skill-dir>
#   CHECK_SKILL_AS=<dir>  check a draft folder as if it were <dir> (the skill's real folder: name,
#                         links and git versions are judged there; a link may also resolve inside
#                         the draft, for a file the draft adds).
#   CHECK_SKILL_BASE=<ref> base ref for the merge-base version (e.g. origin/main, trunk).
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
if [ "$(head -n 1 "$skill" | tr -d '\r')" != "---" ]; then
  report 1 "no frontmatter (first line must be ---)"
  exit 1
fi
fm_end="$(awk '{ sub(/\r$/, "") } NR > 1 && $0 == "---" { print NR; exit }' "$skill")"
[ -n "$fm_end" ] || { report 1 "frontmatter never closed"; exit 1; }
fm_line() { awk -v end="$fm_end" -v key="$1" '{ sub(/\r$/, "") } NR > 1 && NR < end && index($0, key ":") == 1 { print NR; exit }' "$skill"; }
fm_value() {
  local n; n="$(fm_line "$1")"
  [ -n "$n" ] || return 0
  sed -n "${n}p" "$skill" | tr -d '\r' | sed -e "s/^$1:[[:space:]]*//" -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

name="$(fm_value name)"
if [ -z "$name" ]; then
  report 2 "name missing"
else
  n="$(fm_line name)"
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || report "$n" "name is not kebab-case: $name"
  [ "$name" = "$(basename "$as")" ] || report "$n" "name '$name' differs from folder '$(basename "$as")'"
fi

# The description value spans every line from its key to the next top-level key; a block
# indicator (>, |-, …) and an opening quote are not part of it.
for n in $(awk -v end="$fm_end" '
  NR > 1 && NR < end {
    sub(/\r$/, "")
    if (index($0, "description:") == 1) { on = 1; v = $0; sub(/^description:[[:space:]]*/, "", v); sub(/^[>|][-+0-9]*[[:space:]]*$/, "", v); sub(/^["\047]/, "", v) }
    else if (on && $0 ~ /^[A-Za-z0-9_-]+:/) { on = 0; next }
    else if (on) { v = $0 }
    else next
    if (v ~ /[^[:space:]]/) seen = 1
    if (index(v, ":")) print NR
  }
  END { if (!seen) print "missing" }
' "$skill"); do
  case "$n" in missing) report 2 "description missing" ;; *) report "$n" "description contains ':'" ;; esac
done

flag="$(fm_value disable-model-invocation)"
if [ "$flag" = "true" ] && [ "$(fm_value type)" != "flow" ]; then
  report "$(fm_line disable-model-invocation)" "disable-model-invocation: true without type: flow"
fi

# Version at HEAD, at the merge base with the base ref, and in the working tree.
version_of() { awk '{ sub(/\r$/, "") } NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } /^[[:space:]]+version:/ { v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); gsub(/"/, "", v); print v; exit }'; }

# Prints the base ref in short form (see the header), nothing when none or several qualify.
resolve_base() {
  local remote target n ref cand=""
  if [ -n "${CHECK_SKILL_BASE:-}" ]; then printf '%s\n' "$CHECK_SKILL_BASE"; return; fi
  for remote in upstream origin; do
    target="$(git -C "$as" symbolic-ref -q --short "refs/remotes/$remote/HEAD" 2>/dev/null)" || continue
    git -C "$as" rev-parse -q --verify "refs/remotes/$target" >/dev/null 2>&1 && { printf '%s\n' "$target"; return; }
  done
  for n in main master develop development; do
    for ref in "refs/remotes/upstream/$n" "refs/remotes/origin/$n" "refs/heads/$n"; do
      git -C "$as" rev-parse -q --verify "$ref" >/dev/null 2>&1 || continue
      [ -z "$cand" ] || return 0
      cand="${ref#refs/remotes/}"; cand="${cand#refs/heads/}"
      break
    done
  done
  printf '%s\n' "$cand"
}

if [ -d "$as" ] && top="$(git -C "$as" rev-parse --show-toplevel 2>/dev/null)"; then
  rel="SKILL.md"
  [ "$as" = "$top" ] || rel="${as#"$top"/}/SKILL.md"
  base_ref="$(resolve_base)"
  v_head="$(git -C "$as" show "HEAD:$rel" 2>/dev/null | version_of)"
  if [ -z "$base_ref" ]; then
    v_base="base unknown"
  elif ! git -C "$as" rev-parse -q --verify "$base_ref" >/dev/null 2>&1; then
    v_base="no such ref"
  elif ! mb="$(git -C "$as" merge-base HEAD "$base_ref" 2>/dev/null)"; then
    v_base="no merge base"
  elif ! blob="$(git -C "$as" show "$mb:$rel" 2>/dev/null)"; then
    v_base="absent at base"
  else
    v_base="$(printf '%s\n' "$blob" | version_of)"
  fi
  v_tree="$(version_of < "$skill")"
  echo "$skill: version HEAD=${v_head:-none} merge-base(${base_ref:-none})=${v_base:-none} working-tree=${v_tree:-none}"
fi

exit "$fail"
