#!/usr/bin/env python3
"""Scores one self-review run against its fixture's labels (SELF-REVIEW-TEST.md, "Scoring").

Usage:
  score.py --fixture DIR --repo DIR --out DIR [--result result.json] [--report FILE]
           [--tolerance 5] [--against OTHER/score.json] [--case NAME]
  score.py --fixture DIR --repo DIR --verify-labels
  score.py --fixture DIR --oracle      # the labels replayed as a report must score recall 1, precision 1
  score.py --fixture DIR --null        # a clean report must score 0 findings, recall 0

Prints one tab-separated summary line; with --out also writes score.json, score.md, a copy of the
scored report and fixes.diff (the working-tree changes autoaccept applied). Exit 1 when the report
is missing, a structure check fails, a self-check fails or the --against gate fails.
"""
import argparse
import csv
import glob
import json
import os
import re
import shutil
import subprocess
import sys

ITEM = re.compile(r"^(\d+[a-z]?)\.\s+(.*)$")  # "10a." / "10b.": a finding the session split
SPAN = re.compile(r"`([^`]+)`")
# a path-like token inside a backtick span: `path`, `path:12`, `path:~12`, `path:12-15`, `path:12,40-44`,
# `path symbol()`; a known file extension keeps `dto.name`-style code out
SITE = re.compile(r"((?:[\w@.\-]+/|\.\.\./|\u2026/)*[\w@.\-]+\.(?:ts|tsx|js|mjs|py|json|md|html|scss|css|yml|yaml|sql|sh|c|h|go|rs|java|kt|cs|lock|snap|txt|toml|ini|cfg))"
                  r"(?::(~?)(\d[\d,\s-]*))?(?![\w.])")
APPROX = 15  # a `path:~N` site is the reviewer's estimate: it matches within this many lines, never a trap
DISP = re.compile(r"\*\*(fixed|dismissed|deferred|refuted)\*\*")
HEX40 = re.compile(r"`[0-9a-f]{40}`")


def read_tsv(path):
    if not os.path.exists(path):
        return []
    with open(path, newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def parse_sites(spec):
    """'a.py:12|b.py:3-5|c.py:*' -> [(path, lo, hi)], hi None for a whole-file site."""
    out = []
    for part in spec.split("|"):
        path, _, where = part.strip().rpartition(":")
        if where == "*":
            out.append((path, 1, None))
        elif "-" in where:
            lo, hi = where.split("-", 1)
            out.append((path, int(lo), int(hi)))
        else:
            out.append((path, int(where), int(where)))
    return out


def find_report(repo):
    found = glob.glob(os.path.join(repo, ".agents", "plans", "**", "*.SELF-REVIEW*.md"), recursive=True)
    return max(found, key=os.path.getmtime) if found else None


def parse_report(text):
    lines = text.splitlines()
    details_at = next((i for i, l in enumerate(lines) if l.strip() == "<details>"), None)
    visible = lines[:details_at] if details_at is not None else lines
    body = lines[details_at:] if details_at is not None else []
    summary_at = next((i for i, l in enumerate(body) if "</summary>" in l), None)
    checks = {
        "heading": bool(lines) and lines[0].startswith("# Self-review"),
        "outcome_visible": any(l.startswith("**Outcome**") for l in visible),
        "reviewed_visible": any(l.startswith("**Reviewed**") for l in visible),
        "by_visible": any(l.startswith("**By**") and "self-review v" in l for l in visible),
        "details_block": details_at is not None and any(l.strip() == "</details>" for l in body),
        "blank_after_summary": summary_at is not None and summary_at + 1 < len(body) and body[summary_at + 1].strip() == "",
        "intent_collapsed": any(l.startswith("**Intent**") for l in body),
        "project_rules": any(l.startswith("**Project rules**") for l in body),
        "diff_hash": any(l.startswith("**Diff**") and HEX40.search(l) for l in body),
        "metadata_hash": any(l.startswith("**Metadata**") and HEX40.search(l) for l in body),
        "rounds": sum(1 for l in body if l.startswith("## Round")) >= 1,
    }
    findings, current, round_no = [], None, 0
    for l in body:
        if l.startswith("## Round"):
            round_no += 1
        m = ITEM.match(l)
        if m:
            current = {"num": len(findings) + 1, "round": max(round_no, 1), "label": f"R{max(round_no, 1)}.{m.group(1)}", "text": m.group(2)}
            findings.append(current)
        elif current is not None and l.startswith((" ", "\t")) and l.strip():
            current["text"] += " " + l.strip()
        else:
            current = None
    for f in findings:
        f["sites"] = []
        for p, approx, where in (m for span in SPAN.findall(f["text"]) for m in SITE.findall(span)):
            if not where.strip():
                f["sites"].append((p, 1, None))
                continue
            for part in filter(None, (x.strip() for x in where.split(","))):
                lo, _, hi = part.partition("-")
                if lo.isdigit():
                    lo, hi = int(lo), int(hi) if hi.strip().isdigit() else int(lo)
                    f["sites"].append((p, lo - APPROX, hi + APPROX, "approx") if approx else (p, lo, hi))
        d = DISP.search(f["text"])
        f["disposition"] = d.group(1) if d else None
        f["blocking"] = "**blocking**" in f["text"]
    findings = [f for f in findings if f["sites"]]  # numbered lines without a `path` are not findings
    for i, f in enumerate(findings, 1):
        f["num"] = i
    checks["visible_lines"] = sum(1 for l in visible if l.strip())
    return checks, findings


def same_file(finding_path, label_path):
    """A finding may shorten its path (`photo.mapper.ts`, `libs/.../photo-dto.ts`,
    `ui/photo-gallery/photo-gallery.component.ts` for web/libs/ui/photo-gallery/src/lib/\u2026): the
    file name must match and the other segments appear in the label's path, in order."""
    fp = re.split(r"\.\.\.|\u2026", finding_path)[-1].lstrip("./").split("/")
    lp = label_path.lstrip("./").split("/")
    if not fp[-1] or fp[-1] != lp[-1]:
        return False
    rest = iter(lp[:-1])
    return all(seg in rest for seg in fp[:-1])


STOP = {"that", "with", "from", "this", "when", "then", "than", "into", "only", "every", "never", "does",
        "fixed", "dismissed", "deferred", "refuted", "file", "line", "code", "test", "tests", "added", "instead"}


def stems(text):
    """Word stems of 4+ letters, stop words out: `rotates`, `rotated` and `rotate` agree."""
    out = set()
    for w in re.findall(r"[a-z0-9_]+", text.lower()):
        if len(w) < 4 or w in STOP:
            continue
        for suffix in ("ing", "ed", "es", "e", "s"):
            if w.endswith(suffix) and len(w) - len(suffix) >= 4:
                w = w[:-len(suffix)]
                break
        out.add(w)
    return out


def support(finding, label_path, label_text):
    """How far the finding's text backs the label, the file's own name aside: the number of word
    stems it shares with the label's description, plus 2 when code it quotes in backticks appears
    in that description — code with a dot, bang or bracket (`console.log`, `assignee!`) or a long
    name, never a plain short word like `ngOnInit`, which any finding on the file may cite."""
    own = stems(os.path.basename(label_path))
    shared = len((stems(finding["text"]) - own) & (stems(label_text) - own))
    quoted = [s for s in re.findall(r"`([^`]+)`", finding["text"]) if "/" not in s and not re.search(r":[~\d]", s)]
    if any((re.search(r"[^A-Za-z]", s) or len(s) >= 12) and s.lower() in label_text.lower() for s in quoted):
        shared += 2
    return shared


def hits(label_sites, finding, tol, need_line=False, label_text=""):
    """Smallest distance between a finding site and a label site in the same file, or None.
    A cited line hits within `tol` lines. Off by more, up to APPROX (reviewers cite up to a
    dozen lines off), it hits only when the finding's text supports the label by two or more
    (`support`), ranked behind exact hits by how well it does. A finding that cites a file without
    a line hits on any support, after every line match."""
    best = None
    for lp, llo, lhi in label_sites:
        backing = 0 if need_line else support(finding, lp, label_text)
        for site in finding["sites"]:
            fp, flo, fhi = site[:3]
            if not same_file(fp, lp):
                continue
            if need_line and len(site) > 3:
                continue
            if fhi is None:
                if not backing:
                    continue
                dist = APPROX + 0.5
            elif lhi is None:
                dist = 0
            else:
                dist = max(0, llo - fhi, flo - lhi)
                if dist > tol:
                    if dist > APPROX or backing < 2:
                        continue
                    dist = APPROX - min(backing, APPROX - tol - 1)
            if best is None or dist < best:
                best = dist
    return best


def match(defects, traps, findings, tol):
    # Round 1 reviews the change; later rounds review its fixes, so round-1 findings claim first.
    pairs = []
    for d in defects:
        for f in findings:
            dist = hits(parse_sites(d["sites"]), f, tol, label_text=d.get("description", ""))
            if dist is not None:
                pairs.append((f.get("round", 1), dist, d["id"], f["num"]))
    pairs.sort()
    claimed_d, claimed_f, matched = set(), set(), {}
    for _, dist, did, fnum in pairs:
        if did in claimed_d or fnum in claimed_f:
            continue
        claimed_d.add(did)
        claimed_f.add(fnum)
        matched[did] = fnum
    # A finding that names two failures in one line ("swallows save errors; debug print left")
    # credits both: the reader learns of each. Only defects no finding claimed alone go this way,
    # never through an off-line citation, which cannot show the line names both.
    for _, dist, did, fnum in pairs:
        if did not in claimed_d and not tol < dist <= APPROX:
            claimed_d.add(did)
            matched[did] = fnum
    duplicates = [f["num"] for f in findings if f["num"] not in claimed_f
                  and any(hits(parse_sites(d["sites"]), f, tol, label_text=d.get("description", "")) is not None for d in defects)]
    unmatched = [f for f in findings if f["num"] not in claimed_f and f["num"] not in duplicates]
    trap_hits = [(t["id"], f["num"]) for t in traps for f in unmatched if hits(parse_sites(t["sites"]), f, tol, need_line=True) is not None]
    return matched, duplicates, unmatched, trap_hits


def wall_minutes(result_path):
    """Wall clock run.sh measured around the headless run; the result's duration_ms covers only
    its last result when background agents made the session emit several."""
    path = os.path.join(os.path.dirname(result_path), "wall-seconds.txt")
    try:
        return round(int(open(path).read().strip()) / 60, 1)
    except (OSError, ValueError):
        return None


def usage(result_path):
    """Usage of the headless run, summed over the resumes run.sh made (result-resume-N.json)."""
    if not result_path or not os.path.exists(result_path):
        return {"status": "no-result"}
    parts = [result_path] + sorted(glob.glob(os.path.join(os.path.dirname(result_path), "result-resume-*.json")))
    results = []
    for path in parts:
        try:
            with open(path) as f:
                results.append(json.load(f))
        except ValueError:
            return {"status": "bad-result"}
    # A resume continues the session and reports its usage and cost cumulatively: count the last.
    # Turns and subagents it reports per invocation: sum them.
    tokens, cost, turns, subagents, models = 0, 0.0, 0, 0, set()
    for i, r in enumerate(results):
        same = i + 1 < len(results) and results[i + 1].get("session_id") == r.get("session_id")
        turns += r.get("num_turns") or 0
        subagents += (r.get("subagent_stats") or {}).get("spawned") or 0
        if same:
            continue
        for name, m in (r.get("modelUsage") or {}).items():
            models.add(name)
            tokens += sum(m.get(k, 0) or 0 for k in ("inputTokens", "cacheReadInputTokens", "cacheCreationInputTokens", "outputTokens"))
        cost += r.get("total_cost_usd") or 0
    last = results[-1]
    status = last.get("subtype") or "unknown"
    if last.get("is_error"):
        status = "error:" + status
    return {
        "status": status,
        "terminal_reason": last.get("terminal_reason"),
        "tokens": tokens,
        "cost_usd": cost,
        "turns": turns,
        "subagents": subagents,
        "resumes": len(results) - 1,
        "sessions": sorted({r.get("session_id") for r in results if r.get("session_id")}),
        "minutes": wall_minutes(result_path) or round(sum((r.get("duration_ms") or 0) for r in results) / 60000, 1),
        "models": sorted(models),
    }


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, check=False).stdout


def start_state(repo):
    # make-fixture.sh records the reviewed state: HEAD, or a stash-create commit when the change is uncommitted
    path = os.path.join(repo, ".git", "fixture-start")
    return open(path).read().strip() if os.path.exists(path) else "HEAD"


def changed_lines(repo):
    base = git(repo, "merge-base", "main", "HEAD").strip()
    total = 0
    for line in git(repo, "diff", "--numstat", base, start_state(repo)).splitlines():
        a, d, _ = line.split("\t", 2)
        if a != "-":
            total += int(a) + int(d)
    return total


def added_ranges(repo, path):
    base = git(repo, "merge-base", "main", "HEAD").strip()
    out = []
    for line in git(repo, "diff", "-U0", base, start_state(repo), "--", path).splitlines():
        m = re.match(r"^@@ -\S+ \+(\d+)(?:,(\d+))? @@", line)
        if m:
            start, count = int(m.group(1)), int(m.group(2) or 1)
            out.append((start, start + max(count, 1) - 1))
    return out


def verify_labels(fixture, repo):
    ok = True
    for row in read_tsv(os.path.join(fixture, "defects.tsv")) + read_tsv(os.path.join(fixture, "traps.tsv")):
        for path, lo, hi in parse_sites(row["sites"]):
            full = os.path.join(repo, path)
            if not os.path.exists(full):
                print(f"  LABEL {row['id']}: {path} missing in the feature tree"); ok = False; continue
            if hi is None:
                continue
            n = sum(1 for _ in open(full))
            if hi > n:
                print(f"  LABEL {row['id']}: {path}:{lo}-{hi} past end of file ({n} lines)"); ok = False; continue
            if row.get("kind") not in (None, "omission", "missing_test") and not any(a <= hi and lo <= b for a, b in added_ranges(repo, path)):
                print(f"  LABEL {row['id']}: {path}:{lo}-{hi} touches no added line of the diff"); ok = False
    print("labels ok" if ok else "labels INVALID")
    return ok


SKELETON = """# Self-review — feature/x → main

**Outcome** {n} findings — {n} fixed — final round clean

**Reviewed** `0123456` (`feature/x` vs `main`, merge-base diff — 3 files, +10 −2)

**By** harness, model — self-review v1.0, 2026-01-01

<details>
<summary>Review details (1 round)</summary>

**Intent** test

**Project rules** not present

**Diff** `{h}`

**Metadata** `{h}`

## Round 1 — `0123456`, {n} findings

{items}
</details>
"""


def self_check(fixture, oracle):
    defects = read_tsv(os.path.join(fixture, "defects.tsv"))
    traps = read_tsv(os.path.join(fixture, "traps.tsv"))
    items = ""
    if oracle:
        for i, d in enumerate(defects, 1):
            p, lo, hi = parse_sites(d["sites"])[0]
            where = f"{p}:{lo}" if hi in (lo, None) else f"{p}:{lo}-{hi}"
            items += f"{i}. **blocking** `{where}` — {d['description']} → **fixed**\n"
    text = SKELETON.format(n=len(defects) if oracle else 0, h="0" * 40, items=items or "clean\n")
    checks, findings = parse_report(text)
    matched, dups, unmatched, trap_hits = match(defects, traps, findings, 5)
    want = (len(defects), len(defects), 0, 0) if oracle else (0, 0, 0, 0)
    got = (len(findings), len(matched), len(unmatched), len(trap_hits))
    fails = [k for k, v in checks.items() if k != "visible_lines" and not v]
    ok = got == want and not fails
    print(f"{'oracle' if oracle else 'null'} self-check: findings/matched/unmatched/traps={got} want={want} structure={'ok' if not fails else 'FAIL ' + ','.join(fails)}")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fixture", required=True)
    ap.add_argument("--repo")
    ap.add_argument("--out")
    ap.add_argument("--result")
    ap.add_argument("--report")
    ap.add_argument("--tolerance", type=int, default=5)
    ap.add_argument("--against")
    ap.add_argument("--case")
    ap.add_argument("--verify-labels", action="store_true")
    ap.add_argument("--oracle", action="store_true")
    ap.add_argument("--null", action="store_true")
    a = ap.parse_args()

    if a.oracle or a.null:
        sys.exit(0 if self_check(a.fixture, a.oracle) else 1)
    if not a.repo:
        sys.exit("--repo is required")
    if a.verify_labels:
        sys.exit(0 if verify_labels(a.fixture, a.repo) else 1)

    case = a.case or os.path.basename(a.fixture.rstrip("/"))
    defects = read_tsv(os.path.join(a.fixture, "defects.tsv"))
    traps = read_tsv(os.path.join(a.fixture, "traps.tsv"))
    report = a.report or find_report(a.repo)
    use = usage(a.result)
    lines = changed_lines(a.repo)
    exit_code = 0

    if report and os.path.exists(report):
        text = open(report).read()
        checks, findings = parse_report(text)
        matched, dups, unmatched, trap_hits = match(defects, traps, findings, a.tolerance)
        # findings credited with two or more defects: distinct mistakes the reviewer put on one line
        merged = sorted({n for n in matched.values() if list(matched.values()).count(n) > 1})
    else:
        text, checks, findings, matched, dups, unmatched, trap_hits, merged = "", {}, [], {}, [], [], [], []
        use["status"] = use.get("status", "") + "+no-report"
        exit_code = 1

    structure_fails = [k for k, v in checks.items() if k != "visible_lines" and not v]
    if report and structure_fails:
        exit_code = 1
    blocking = [d for d in defects if d.get("blocking") == "yes"]
    recall = round(len(matched) / len(defects), 2) if defects else None
    blocking_recall = round(sum(1 for d in blocking if d["id"] in matched) / len(blocking), 2) if blocking else None
    # A finding the skill refuted itself never reaches the author as an action item.
    acted = [f for f in findings if f["disposition"] != "refuted"]
    precision = round(len(set(matched.values()) & {f['num'] for f in acted}) / len(acted), 2) if acted else None
    tokens = use.get("tokens")
    score = {
        "case": case, "status": use.get("status"), "report": report,
        "defects": len(defects), "found": len(matched), "recall": recall,
        "blocking_recall": blocking_recall, "findings": len(findings), "precision": precision,
        "unmatched": [f["label"] for f in unmatched],
        "duplicates": [f["label"] for f in findings if f["num"] in dups],
        "trap_hits": trap_hits, "merged": [f["label"] for f in findings if f["num"] in merged], "missed": [d["id"] for d in defects if d["id"] not in matched],
        "matched": {d: next(f["label"] for f in findings if f["num"] == n) for d, n in matched.items()},
        "structure_fails": structure_fails,
        "visible_lines": checks.get("visible_lines"),
        "dispositions": {k: sum(1 for f in findings if f["disposition"] == k) for k in ("fixed", "dismissed", "deferred", "refuted")},
        "changed_lines": lines, "tokens_per_line": round(tokens / lines) if tokens and lines else None,
        **{k: use.get(k) for k in ("tokens", "cost_usd", "turns", "subagents", "minutes", "models", "terminal_reason")},
    }

    if a.against and os.path.exists(a.against):
        base = json.load(open(a.against))
        gate = []
        if base.get("recall") is not None and recall is not None and recall < base["recall"] - 0.10:
            gate.append(f"recall {recall} < baseline {base['recall']} - 0.10")
        if base.get("tokens") and tokens and tokens > base["tokens"] * 1.25:
            gate.append(f"tokens {tokens:,} > baseline {base['tokens']:,} + 25%")
        score["gate"] = gate or ["pass"]
        if gate:
            exit_code = 1

    if a.out:
        os.makedirs(a.out, exist_ok=True)
        json.dump(score, open(os.path.join(a.out, "score.json"), "w"), indent=2)
        dest = os.path.join(a.out, "report.md")
        if text and not (os.path.exists(dest) and os.path.samefile(report, dest)):
            shutil.copy(report, dest)
        with open(os.path.join(a.out, "fixes.diff"), "w") as f:
            f.write(git(a.repo, "diff", start_state(a.repo)))
        with open(os.path.join(a.out, "score.md"), "w") as f:
            f.write(f"# {case}\n\n")
            f.write("| metric | value |\n| --- | --- |\n")
            for k in ("status", "defects", "found", "recall", "blocking_recall", "findings", "precision",
                      "duplicates", "trap_hits", "merged", "tokens", "tokens_per_line", "cost_usd", "turns", "subagents",
                      "minutes", "changed_lines", "visible_lines", "structure_fails", "gate"):
                if k in score:
                    f.write(f"| {k} | {score[k]} |\n")
            f.write("\n## Matched\n\n" + "".join(f"- {d['id']} → finding {score['matched'][d['id']]}: {d['description']}\n" for d in defects if d["id"] in matched))
            f.write("\n## Missed\n\n" + "".join(f"- {d['id']} ({d['kind']}, blocking={d['blocking']}): {d['description']}\n" for d in defects if d["id"] not in matched))
            f.write("\n## Unmatched findings (false-positive candidates; read them)\n\n" + "".join(f"- {u['label']}. {u['text']}\n" for u in unmatched))
            if trap_hits:
                label = {x["num"]: x["label"] for x in findings}
                f.write("\n## Traps flagged\n\n" + "".join(f"- {t} by finding {label[n]}\n" for t, n in trap_hits))

    cols = ["case", "status", "defects", "found", "recall", "blocking_recall", "findings", "precision",
            "trap_hits", "merged", "tokens", "tokens_per_line", "cost_usd", "turns", "subagents", "minutes", "structure_fails"]
    counted = {"trap_hits": len(score["trap_hits"]), "merged": len(score["merged"]),
               "structure_fails": ",".join(structure_fails) or "ok"}
    row = [counted.get(c, score[c]) for c in cols]
    print("\t".join("-" if v is None else str(v) for v in row))
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
