#!/usr/bin/env python3
"""Puts two harness runs side by side (SELF-REVIEW-TEST.md, "Old vs new").

Usage: compare.py <run-dir-A> <run-dir-B> [case ...]
Each run dir is a runs/<timestamp>/ of run.sh. For every case present in both, prints the cost
and quality metrics of A and B, the planted defects each matched and missed, and the unmatched
finding counts. Read-only; exit 1 when no case is shared.
"""
import json
import os
import sys

# no "turns": with background agents the result's num_turns covers only its last turn
METRICS = ["status", "tokens", "tokens_per_line", "cost_usd", "subagents", "minutes",
           "recall", "blocking_recall", "findings", "precision", "structure_fails"]


def load(run, case):
    path = os.path.join(run, case, "score.json")
    if not os.path.exists(path):
        return None
    with open(path) as f:
        score = json.load(f)
    ref = os.path.join(run, case, "skills-ref.txt")
    score["skills"] = open(ref).read().strip() if os.path.exists(ref) else "?"
    return score


def fmt(v):
    if isinstance(v, float):
        return f"{v:.2f}"
    if isinstance(v, list):
        return ",".join(map(str, v)) or "-"
    return "-" if v is None else str(v)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    a, b, wanted = sys.argv[1], sys.argv[2], sys.argv[3:]
    cases = wanted or sorted({d for r in (a, b) for d in os.listdir(r) if os.path.isdir(os.path.join(r, d, "")) and os.path.exists(os.path.join(r, d, "score.json"))})
    shared = 0
    for case in cases:
        sa, sb = load(a, case), load(b, case)
        if not (sa and sb):
            continue
        shared += 1
        print(f"\n## {case}\n")
        print(f"| metric | A ({sa['skills']}) | B ({sb['skills']}) |\n| --- | --- | --- |")
        for m in METRICS:
            print(f"| {m} | {fmt(sa.get(m))} | {fmt(sb.get(m))} |")
        ma, mb = set(sa.get("matched", {})), set(sb.get("matched", {}))
        print(f"| matched | {fmt(sorted(ma))} | {fmt(sorted(mb))} |")
        print(f"| missed | {fmt(sa.get('missed'))} | {fmt(sb.get('missed'))} |")
        print(f"| unmatched findings | {len(sa.get('unmatched', []))} | {len(sb.get('unmatched', []))} |")
        print(f"| trap hits | {len(sa.get('trap_hits', []))} | {len(sb.get('trap_hits', []))} |")
        if ma != mb:
            print(f"\nonly A found: {fmt(sorted(ma - mb))}; only B found: {fmt(sorted(mb - ma))}")
        if sa.get("tokens") and sb.get("tokens"):
            print(f"\ntokens B/A = {sb['tokens'] / sa['tokens']:.2f}")
    if not shared:
        sys.exit("no case with a score.json in both run dirs")


if __name__ == "__main__":
    main()
