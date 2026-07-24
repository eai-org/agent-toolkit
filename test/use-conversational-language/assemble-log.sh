#!/bin/bash
# Assembles a LANGUAGE-TEST run log from a run dir (see LANGUAGE-TEST.md, "Run log").
# Usage: ./assemble-log.sh <run-dir> <output.md>
# Expects in <run-dir>: header.md, scenarios.tsv (id, judge context, brief),
# iter<N>/texts/<id>.txt, iter<N>/verdicts/<id>.<model>.txt, triage-iter<N>.md (optional per
# iteration), outcome.md. Iterations, scenario order and panel come from what's on disk.
set -eu
RUN="${1:?usage: assemble-log.sh <run-dir> <output.md>}"
LOG="${2:?usage: assemble-log.sh <run-dir> <output.md>}"

{
  cat "$RUN/header.md"
  echo
  echo "## Scenarios"
  echo
  while IFS=$'\t' read -r id ctx brief; do
    echo "- **\`$id\`** — \"$ctx\""
    printf '%s\n' "$brief" | fold -s -w 98 | sed 's/^/  /; s/[[:space:]]*$//'
  done < "$RUN/scenarios.tsv"
  echo

  for iter in "$RUN"/iter*/; do
    n="$(basename "$iter" | sed 's/^iter//')"
    echo "## Iteration $n"
    echo
    while IFS=$'\t' read -r id ctx brief; do
      [ -f "$iter/texts/$id.txt" ] || continue
      echo "### $id"
      echo
      echo '```'
      cat "$iter/texts/$id.txt"
      echo
      echo '```'
      echo
      for vf in "$iter/verdicts/$id".*.txt; do
        [ -f "$vf" ] || continue
        m="$(basename "$vf" .txt)"
        m="${m#"$id".}"
        verdict="$(head -1 "$vf" | tr -d '\r')"
        echo "**$m: $verdict**"
        echo
        tail -n +2 "$vf" | sed '/./,$!d' | fold -s -w 100 | sed 's/[[:space:]]*$//'
        echo
      done
    done < "$RUN/scenarios.tsv"
    if [ -f "$RUN/triage-iter$n.md" ]; then
      cat "$RUN/triage-iter$n.md"
      echo
    fi
  done

  echo "## Outcome"
  echo
  cat "$RUN/outcome.md"
} > "$LOG"
echo "written: $LOG"
wc -l "$LOG"
