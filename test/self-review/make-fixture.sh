#!/usr/bin/env bash
#
# Builds the throwaway repo for one fixture of SELF-REVIEW-TEST.md.
#
# Usage: make-fixture.sh <fixture-dir> <repo-dir> [name]
#
# <repo-dir> must not exist. The fixture's base/ is committed on main; change/ is laid over it and
# committed on feature/<name> in one commit whose subject is intent.txt's first sentence, paths
# listed in change/.deleted removed first. <name> defaults to the fixture dir's basename. intent.txt becomes
# .agents/plans/<name>/<name>.REQUIREMENTS.md, the planning home the skill reads its intent from,
# and the toolkit's working-tree skills self-review, fresh-eyes-review and
# explain-in-simple-language are linked into .claude/skills/, so a headless run with
# `--setting-sources project` exercises the checkout under test; SKILLS_REF=<git ref> (e.g. HEAD,
# main, a tag) exports those three skills from that ref instead, for a before/after comparison.
# Both dirs are gitignored by the fixture, so the tree ends clean. Git is fenced below <repo-dir>'s
# parent: a failed init must never reach this toolkit's own repo.
set -u

fixture="${1:?usage: make-fixture.sh <fixture-dir> <repo-dir> [name]}"
repo="${2:?usage: make-fixture.sh <fixture-dir> <repo-dir> [name]}"
name="${3:-$(basename "$fixture")}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
toolkit="$(cd "$here/../.." && pwd -P)"

die() { echo "make-fixture: $*" >&2; exit 1; }
[ -d "$fixture/base" ] && [ -d "$fixture/change" ] && [ -f "$fixture/intent.txt" ] ||
  die "$fixture lacks base/, change/ or intent.txt"
[ ! -e "$repo" ] || die "$repo exists"
mkdir -p "$repo" || die "cannot create $repo"
repo="$(cd "$repo" && pwd -P)"
export GIT_CEILING_DIRECTORIES="$(dirname "$repo")"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME="Fixture Author" GIT_AUTHOR_EMAIL="author@example.invalid"
export GIT_COMMITTER_NAME="Fixture Author" GIT_COMMITTER_EMAIL="author@example.invalid"

g() { git -C "$repo" "$@"; }

g -c init.defaultBranch=main init -q --template= || die "git init failed"
[ "$(g rev-parse --show-toplevel)" = "$repo" ] || die "$repo is not its own repo root"

cp -R "$fixture/base/." "$repo/" || die "copying base failed"
g add -A && g commit -q -m "chore: baseline" || die "baseline commit failed"
g checkout -q -b "feature/$name" || die "branch failed"

if [ -f "$fixture/change/.deleted" ]; then
  while IFS= read -r p; do [ -n "$p" ] && rm -rf "$repo/${p#/}"; done < "$fixture/change/.deleted"
fi
(cd "$fixture/change" && find . -type f -not -name .deleted -print0) |
  while IFS= read -r -d '' f; do
    mkdir -p "$repo/$(dirname "$f")" && cp "$fixture/change/$f" "$repo/$f" || exit 1
  done || die "copying change failed"

# First sentence of the intent, lower-cased first letter, cut at a word boundary within 72 chars.
subject="$(head -n 1 "$fixture/intent.txt" | sed -E 's/^([^.:]*)[.:].*$/\1/' |
  awk '{ $1 = tolower(substr($1, 1, 1)) substr($1, 2); s = ""; for (i = 1; i <= NF; i++) { if (length(s) + length($i) + 1 > 66) break; s = (s == "" ? $i : s " " $i) } print s }')"
g add -A && g commit -q -m "feat: ${subject}" || die "feature commit failed"

plan="$repo/.agents/plans/$name"
mkdir -p "$plan" "$repo/.claude/skills" || die "cannot create plan or skills dir"
{
  echo "# $name — requirements"
  echo
  cat "$fixture/intent.txt"
} > "$plan/$name.REQUIREMENTS.md"
skills=(self-review fresh-eyes-review explain-in-simple-language)
if [ -n "${SKILLS_REF:-}" ]; then
  git -C "$toolkit" archive "$SKILLS_REF" "${skills[@]/#/skills/}" | tar -x -C "$repo/.claude" ||
    die "exporting skills from $SKILLS_REF failed"
  for s in "${skills[@]}"; do [ -f "$repo/.claude/skills/$s/SKILL.md" ] || die "$s missing at $SKILLS_REF"; done
else
  for s in "${skills[@]}"; do
    [ -d "$toolkit/skills/$s" ] || die "toolkit skill $s not found"
    ln -s "$toolkit/skills/$s" "$repo/.claude/skills/$s" || die "linking $s failed"
  done
fi
echo "${SKILLS_REF:-working-tree}" > "$repo/.claude/skills-ref"

[ -z "$(g status --porcelain)" ] || die "tree not clean after setup: $(g status --porcelain | head -3)"
echo "$repo: $(g rev-parse --abbrev-ref HEAD) at $(g rev-parse --short HEAD), $(g diff --shortstat main...HEAD)"
