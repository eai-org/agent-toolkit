#!/usr/bin/env bash
#
# Checks markdown files against the writing conventions a script can hold: prose lines longer
# than the .editorconfig max_line_length, counted in characters, and relative inline links
# (`[text](target)`; titles and reference-style links are not parsed) that do not resolve (links
# inside backtick spans are templates, not checked). Skipped for the length check:
# YAML frontmatter, fenced code, table rows, lines holding a URL or a link, and a line whose
# overflow starts inside a backtick span (a command stays on one line). No max_line_length
# applies → the length check is skipped.
#
# Usage: check-doc.sh <file.md> [...]
#   CHECK_DOC_AS=<path>  check a single file as if it lived at <path> (a draft in a scratch dir:
#                        .editorconfig lookup and link resolution use <path>'s directory).
# One line per failure, `file:line: message`; exit 1 when any was found, 2 on usage errors.

set -u

[ $# -ge 1 ] || { echo "usage: check-doc.sh <file.md> [...]" >&2; exit 2; }
if [ -n "${CHECK_DOC_AS:-}" ] && [ $# -ne 1 ]; then
  echo "check-doc: CHECK_DOC_AS takes exactly one file" >&2; exit 2
fi

# ${#line} counts characters only under a UTF-8 locale; keep the inherited one when it already
# counts "é" as 1, else take the first name that does.
probe="é"
if [ "${#probe}" -ne 1 ]; then
  for loc in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8 UTF-8; do
    { export LC_ALL="$loc"; } 2>/dev/null
    [ "${#probe}" -eq 1 ] && break
    unset LC_ALL
  done
fi

# Prints the max_line_length that applies to .md files, from the nearest .editorconfig upward
# (sections [*], [*.md] or a brace list naming md); stops at a file declaring root = true.
max_line_length() {
  local dir="$1" cfg out
  while :; do
    cfg="$dir/.editorconfig"
    if [ -f "$cfg" ]; then
      out="$(awk '
        /^[[:space:]]*\[/ {
          s = $0; sub(/^[[:space:]]*\[/, "", s); sub(/\].*$/, "", s)
          on = (s == "*" || s == "*.md" || s ~ /[{,](\*\.)?md[,}]/); next
        }
        tolower($0) ~ /^[[:space:]]*root[[:space:]]*=[[:space:]]*true/ { root = 1 }
        on && tolower($0) ~ /^[[:space:]]*max_line_length[[:space:]]*=/ {
          v = $0; sub(/^[^=]*=[[:space:]]*/, "", v); sub(/[[:space:]]*$/, "", v); val = v
        }
        END { if (val != "" && val != "off") print val; if (root) print "root" }
      ' "$cfg")"
      case "$out" in
        root) return ;;
        *root) printf '%s\n' "${out%root}"; return ;;
        "") ;;
        *) printf '%s\n' "$out"; return ;;
      esac
    fi
    case "$dir" in /|.) return ;; esac
    dir="$(dirname "$dir")"
  done
}

fail=0
report() { printf '%s:%s: %s\n' "$1" "$2" "$3"; fail=1; }

check_file() {
  local f="$1" as="${CHECK_DOC_AS:-$1}" dir cfgdir max line n=0 fence_re="" in_fm=0 rest target prefix ticks
  [ -f "$f" ] || { echo "check-doc: no such file: $f" >&2; fail=1; return; }
  # A target folder that does not exist yet (a draft for a new skill) still names where the
  # .editorconfig lookup starts; links then resolve beside the draft itself.
  cfgdir="$(dirname "$as")"
  case "$cfgdir" in /*) ;; *) cfgdir="$PWD/$cfgdir" ;; esac
  dir="$(cd "$cfgdir" 2>/dev/null && pwd -P)" || dir="$(cd "$(dirname "$f")" && pwd -P)"
  max="$(max_line_length "$cfgdir")"
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if [ "$n" -eq 1 ] && [ "$line" = "---" ]; then in_fm=1; continue; fi
    if [ "$in_fm" -eq 1 ]; then [ "$line" = "---" ] && in_fm=0; continue; fi
    if [ -n "$fence_re" ]; then
      [[ "$line" =~ $fence_re ]] && fence_re=""
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*(\`{3,}|~{3,}) ]]; then
      fence_re="^[[:space:]]*[${BASH_REMATCH[1]:0:1}]{${#BASH_REMATCH[1]},}[[:space:]]*\$"
      continue
    fi

    rest="$line"
    while [[ "$rest" =~ \`[^\`]*\` ]]; do rest="${rest/"${BASH_REMATCH[0]}"/}"; done
    while [[ "$rest" =~ \]\(([^\)[:space:]]+)\) ]]; do
      target="${BASH_REMATCH[1]}"
      rest="${rest#*"${BASH_REMATCH[0]}"}"
      case "$target" in *://*|mailto:*|\#*) continue ;; esac
      target="${target%%#*}"
      [ -e "$dir/$target" ] || report "$f" "$n" "dangling link: $target"
    done

    [ -n "$max" ] && [ "${#line}" -gt "$max" ] || continue
    case "$line" in
      *://*|*']('*) continue ;;
    esac
    [[ "$line" =~ ^[[:space:]]*\| ]] && continue
    prefix="${line:0:$max}"
    ticks="${prefix//[^\`]/}"
    [ $(( ${#ticks} % 2 )) -eq 1 ] && continue
    report "$f" "$n" "line is ${#line} characters, max $max"
  done < "$f"
}

for f in "$@"; do check_file "$f"; done
exit "$fail"
