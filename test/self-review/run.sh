#!/usr/bin/env bash
#
# Harness for skills/self-review (and the fresh-eyes-review it drives): see SELF-REVIEW-TEST.md.
#
# Usage:
#   bash test/self-review/run.sh [case ...]
#   MODEL=sonnet BUDGET_BIG=3 bash test/self-review/run.sh big-pr                  # ~0.65 USD
#   MODEL=sonnet SKILLS_REF=HEAD BUDGET_BIG=3 bash test/self-review/run.sh big-pr  # old skills
#
# Cases: selfcheck (free, deterministic: builds every fixture, validates its labels, scores an
# oracle and a null report), small-defects, small-clean, small-uncommitted (small-defects with its
# edits to existing files left uncommitted), big-pr, incident. Default: selfcheck small-defects
# small-clean. The LLM cases run `/self-review autoaccept` headlessly in a fixture repo
# and cost real tokens; see the budget variables.
#
# Env:
#   MODEL         --model for the headless run (default: the CLI's default model)
#   BUDGET_SMALL  --max-budget-usd for small-* (default 8); BUDGET_BIG for big-pr (default 30);
#                 BUDGET_INCIDENT for incident (default 10)
#   MODULES       entity count of the generated big-pr fixture (default 40, min 12)
#   FIXTURE_ROOT  where fixture repos are built (default: a fresh mktemp dir; never inside this
#                 repo, whose AGENTS.md would otherwise load into the run)
#   SKILLS_REF    run the skills as exported from this git ref (e.g. HEAD = the committed version)
#                 instead of the working tree; compare two run dirs with compare.py
#   BASELINE_DIR  gate each case's score against <dir>/<case>.json (recall −0.10, tokens +25%)
#   REPEAT        runs per LLM case (default 1); above 1 each run goes to <case>.<n>/
#
# A run that ends on a question with no report yet is resumed with "go with your recommendation",
# at most twice (result-resume-N.json); the scorer counts the session's cumulative usage once.
#
# Output: runs/<timestamp>-<suffix>/<case>/{result.json,claude.err,report.md,score.json,score.md,fixes.diff}
# and runs/<timestamp>/summary.tsv. Exits non-zero when selfcheck fails, a headless run errored or
# produced no report, a structure check failed, or a baseline gate failed.

set -u -o pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FIXTURES="$HARNESS_DIR/fixtures"
mkdir -p "$HARNESS_DIR/runs" || exit 2
# unique even when several runners start in the same second
RUNS="$(mktemp -d "$HARNESS_DIR/runs/$(date +%Y%m%d-%H%M%S)-XXXX")" || exit 2
FIXTURE_ROOT="${FIXTURE_ROOT:-$(mktemp -d -t self-review-fixtures)}"
MODEL="${MODEL:-}"
BUDGET_SMALL="${BUDGET_SMALL:-8}"
BUDGET_BIG="${BUDGET_BIG:-30}"
BUDGET_INCIDENT="${BUDGET_INCIDENT:-10}"
MODULES="${MODULES:-40}"
BASELINE_DIR="${BASELINE_DIR:-}"
REPEAT="${REPEAT:-1}"
mkdir -p "$RUNS" "$FIXTURE_ROOT" || exit 2

HEADER="case	status	defects	found	recall	blocking_recall	findings	precision	trap_hits	merged	tokens	tokens_per_line	cost_usd	turns	subagents	minutes	structure"
echo "$HEADER" > "$RUNS/summary.tsv"
failed=0

fixture_for() {
  case "$1" in
    big-pr)
      [ -d "$RUNS/big-pr-fixture" ] || python3 -I "$HARNESS_DIR/gen-big-pr.py" "$RUNS/big-pr-fixture" --modules "$MODULES" >/dev/null || return 1
      echo "$RUNS/big-pr-fixture" ;;
    incident)
      [ -d "$RUNS/incident-fixture" ] || python3 -I "$HARNESS_DIR/gen-incident.py" "$RUNS/incident-fixture" >/dev/null || return 1
      echo "$RUNS/incident-fixture" ;;
    small-uncommitted) echo "$FIXTURES/small-defects" ;;
    *) [ -d "$FIXTURES/$1" ] || return 1; echo "$FIXTURES/$1" ;;
  esac
}

build() {  # <case> <fixture> <repo>
  local mode=""
  [ "$1" = small-uncommitted ] && mode=1
  UNCOMMITTED="$mode" bash "$HARNESS_DIR/make-fixture.sh" "$2" "$3" "$1"
}

selfcheck() {
  local ok=1 fx repo
  for c in small-defects small-clean small-uncommitted big-pr incident; do
    fx="$(fixture_for "$c")" || { echo "  no fixture for $c"; ok=0; continue; }
    repo="$FIXTURE_ROOT/selfcheck/$c"
    build "$c" "$fx" "$repo" >"$RUNS/selfcheck-$c.log" 2>&1 || { echo "  make-fixture failed for $c (see $RUNS/selfcheck-$c.log)"; ok=0; continue; }
    echo "  $c: $(tail -n 1 "$RUNS/selfcheck-$c.log")"
    python3 -I "$HARNESS_DIR/score.py" --fixture "$fx" --repo "$repo" --verify-labels | sed 's/^/    /' || ok=0
    python3 -I "$HARNESS_DIR/score.py" --fixture "$fx" --oracle | sed 's/^/    /' || ok=0
    python3 -I "$HARNESS_DIR/score.py" --fixture "$fx" --null | sed 's/^/    /' || ok=0
  done
  [ "$ok" -eq 1 ]
}

run_case() {  # <case> <run name>
  local c="$1" name="$2" fx repo out budget rc
  fx="$(fixture_for "$c")" || { echo "FAIL $name: no fixture"; return 1; }
  repo="$FIXTURE_ROOT/$name"; out="$RUNS/$name"; mkdir -p "$out"
  build "$c" "$fx" "$repo" >"$out/make-fixture.log" 2>&1 || { echo "FAIL $name: make-fixture (see $out/make-fixture.log)"; return 1; }
  case "$c" in big-pr) budget="$BUDGET_BIG" ;; incident) budget="$BUDGET_INCIDENT" ;; *) budget="$BUDGET_SMALL" ;; esac
  echo "RUN  $name in $repo (skills: ${SKILLS_REF:-working tree}, budget \$$budget${MODEL:+, model $MODEL}) ..."
  echo "${SKILLS_REF:-working-tree}" > "$out/skills-ref.txt"
  local t0; t0=$(date +%s)
  (cd "$repo" && claude -p --setting-sources project --dangerously-skip-permissions \
      --output-format json --max-budget-usd "$budget" ${MODEL:+--model "$MODEL"} \
      "/self-review autoaccept") >"$out/result.json" 2>"$out/claude.err"
  rc=$?
  # Autoaccept still asks before a fix that reshapes the change; a headless run then ends without
  # a report. Answer as an author who takes the recommendation, at most twice.
  local n sid
  for n in 1 2; do
    [ "$rc" -eq 0 ] || break
    find "$repo/.agents/plans" -name '*.SELF-REVIEW*.md' 2>/dev/null | grep -q . && break
    sid="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("session_id",""))' "$out/result.json" 2>/dev/null)"
    [ -n "$sid" ] || break
    echo "  no report yet: resuming $sid with the recommendation ($n)"
    (cd "$repo" && claude -p --resume "$sid" --setting-sources project --dangerously-skip-permissions \
        --output-format json --max-budget-usd "$budget" ${MODEL:+--model "$MODEL"} \
        "Go with your recommendation on every open question, then finish the review.") \
        >"$out/result-resume-$n.json" 2>>"$out/claude.err"
    rc=$?
  done
  echo $(( $(date +%s) - t0 )) > "$out/wall-seconds.txt"
  [ "$rc" -eq 0 ] || echo "  headless run exited $rc (see $out/claude.err)"
  python3 -I "$HARNESS_DIR/score.py" --fixture "$fx" --repo "$repo" --result "$out/result.json" \
      --out "$out" --case "$name" ${BASELINE_DIR:+--against "$BASELINE_DIR/$c.json"} | tee -a "$RUNS/summary.tsv"
  local src=$?
  [ "$rc" -eq 0 ] && [ "$src" -eq 0 ]
}

cases=("$@")
[ ${#cases[@]} -gt 0 ] || cases=(selfcheck small-defects small-clean)
for c in "${cases[@]}"; do
  if [ "$c" = selfcheck ]; then
    echo "selfcheck:"
    if selfcheck; then echo "PASS selfcheck"; else echo "FAIL selfcheck"; failed=1; fi
  elif [ "$REPEAT" -gt 1 ]; then
    for n in $(seq 1 "$REPEAT"); do run_case "$c" "$c.$n" || failed=1; done
  else
    run_case "$c" "$c" || failed=1
  fi
done

echo
echo "summary ($RUNS/summary.tsv):"
column -t -s "	" "$RUNS/summary.tsv" 2>/dev/null || cat "$RUNS/summary.tsv"
echo "fixture repos: $FIXTURE_ROOT"
exit "$failed"
