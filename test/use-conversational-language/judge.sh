#!/bin/bash
# Judge runner for LANGUAGE-TEST.md: runs the blind panel over one iteration's texts.
# Usage: [PANEL="model ..."] ./judge.sh <run-dir> <iteration-number>
# Reads <run-dir>/scenarios.tsv (id, judge context, brief) and <run-dir>/iter<N>/texts/<id>.txt;
# writes <run-dir>/iter<N>/verdicts/<id>.<model>.txt. Call failures land in verdicts/_failures.log.
set -u
RUN="${1:?usage: judge.sh <run-dir> <iteration-number>}"
N="${2:?usage: judge.sh <run-dir> <iteration-number>}"
TEXTS="$RUN/iter$N/texts"
OUT="$RUN/iter$N/verdicts"
SCEN="$RUN/scenarios.tsv"
PANEL="${PANEL:-claude-fable-5 claude-opus-4-8 claude-sonnet-5}"
mkdir -p "$OUT"

judge_once() {
  local id="$1" model="$2" text ctx prompt d
  text="$(cat "$TEXTS/$id.txt")"
  ctx="$(awk -F'\t' -v id="$id" '$1 == id { print $2; exit }' "$SCEN")"
  prompt="Guess whether this text has been written by a human or is AI generated.
First line of your reply: exactly HUMAN or AI. Then briefly explain why.
Judge from the text alone.

Context: $ctx

Input text:

$text"
  d="$(mktemp -d)"
  (cd "$d" && claude -p --model "$model" --setting-sources "" "$prompt") \
    > "$OUT/$id.$model.txt" 2> "$OUT/$id.$model.err"
}

judge() {
  local id="$1" model="$2" first
  judge_once "$id" "$model" || { echo "CALL-FAILED $id $model" >> "$OUT/_failures.log"; return; }
  # malformed verdict (first line not HUMAN/AI): rerun once, per the harness
  first="$(head -1 "$OUT/$id.$model.txt" | tr -d '\r')"
  if [ "$first" != "HUMAN" ] && [ "$first" != "AI" ]; then
    judge_once "$id" "$model" || echo "CALL-FAILED-RERUN $id $model" >> "$OUT/_failures.log"
  fi
}
export -f judge judge_once
export TEXTS OUT SCEN

for f in "$TEXTS"/*.txt; do
  id="$(basename "$f" .txt)"
  for m in $PANEL; do
    echo "$id $m"
  done
done | xargs -P 10 -n 2 bash -c 'judge "$0" "$1"'

echo "ALL DONE"
