#!/usr/bin/env python3
"""Puts two sets of harness runs side by side (SELF-REVIEW-TEST.md, "Old vs new").

Usage: compare.py <run-dir-A>[,<run-dir-A2>...] <run-dir-B>[,<run-dir-B2>...] [case ...]
Each run dir is a runs/<timestamp>-<suffix>/ of run.sh; a side may list several, and a case's
samples are its <case>/ and <case>.<n>/ dirs across them. For every case present on both sides,
prints the cost and quality metrics of A and B (median and range over several samples), how often
each planted defect was matched, and the unmatched and merged finding counts. Read-only; exit 1
when no case is shared.
"""
import json
import os
import re
import statistics
import sys

# no "turns": with background agents the result's num_turns covers only its last turn
METRICS = ["tokens", "tokens_per_line", "cost_usd", "subagents", "minutes",
           "recall", "blocking_recall", "findings", "precision"]


def samples(side, case):
    found = []
    for run in side.split(","):
        if not os.path.isdir(run):
            continue
        for d in sorted(os.listdir(run)):
            if re.fullmatch(re.escape(case) + r"(\.\d+)?", d) and os.path.exists(os.path.join(run, d, "score.json")):
                with open(os.path.join(run, d, "score.json")) as f:
                    score = json.load(f)
                ref = os.path.join(run, d, "skills-ref.txt")
                score["skills"] = open(ref).read().strip() if os.path.exists(ref) else "?"
                score.setdefault("merged", [n for n in set(score.get("matched", {}).values())
                                            if list(score["matched"].values()).count(n) > 1])
                found.append(score)
    return found


def cases_in(side):
    names = set()
    for run in side.split(","):
        if os.path.isdir(run):
            names |= {re.sub(r"\.\d+$", "", d) for d in os.listdir(run) if os.path.exists(os.path.join(run, d, "score.json"))}
    return names


def summary(values):
    values = [v for v in values if isinstance(v, (int, float))]
    if not values:
        return "-"
    f = (lambda v: f"{v:,.0f}") if max(values) >= 1000 else (lambda v: f"{v:.2f}".rstrip("0").rstrip("."))
    med = statistics.median(values)
    return f(med) if len(values) == 1 else f"{f(med)} ({f(min(values))}–{f(max(values))})"


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    a, b, wanted = sys.argv[1], sys.argv[2], sys.argv[3:]
    shared = 0
    for case in wanted or sorted(cases_in(a) | cases_in(b)):
        sa, sb = samples(a, case), samples(b, case)
        if not (sa and sb):
            continue
        shared += 1
        skills = lambda s: ",".join(sorted({x["skills"] for x in s}))
        print(f"\n## {case}\n")
        print(f"| metric | A ({skills(sa)}, n={len(sa)}) | B ({skills(sb)}, n={len(sb)}) |\n| --- | --- | --- |")
        print(f"| status | {','.join(sorted({x.get('status') or '?' for x in sa}))} | {','.join(sorted({x.get('status') or '?' for x in sb}))} |")
        for m in METRICS:
            print(f"| {m} | {summary([x.get(m) for x in sa])} | {summary([x.get(m) for x in sb])} |")
        for label, key in (("found", "matched"), ("unmatched findings", "unmatched"),
                           ("merged findings", "merged"), ("trap hits", "trap_hits")):
            print(f"| {label} | {', '.join(str(len(x.get(key) or [])) for x in sa)} | {', '.join(str(len(x.get(key) or [])) for x in sb)} |")
        defects = sorted({d for x in sa + sb for d in list(x.get("matched", {})) + (x.get("missed") or [])},
                         key=lambda d: (len(d), d))
        rate = lambda s, d: sum(1 for x in s if d in x.get("matched", {}))
        uneven = [f"{d} {rate(sa, d)}/{len(sa)} vs {rate(sb, d)}/{len(sb)}" for d in defects
                  if rate(sa, d) / len(sa) != rate(sb, d) / len(sb)]
        if uneven:
            print(f"\nmatched A vs B, where they differ: {'; '.join(uneven)}")
        ta = statistics.median([x["tokens"] for x in sa if x.get("tokens")] or [0])
        tb = statistics.median([x["tokens"] for x in sb if x.get("tokens")] or [0])
        if ta and tb:
            print(f"\nmedian tokens B/A = {tb / ta:.2f}")
    if not shared:
        sys.exit("no case with a score.json on both sides")


if __name__ == "__main__":
    main()
