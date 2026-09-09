---
name: run-nx-checks
description: Run nx format, lint, test, and build on affected or specified projects, then fix unambiguous failures
context: fork
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
license: MIT
metadata:
  version: "1.8"
---

# Run Nx Checks

Run format, lint, test, build. Fix unambiguous failures. Report anything judgment-laden.

## Arguments

`$ARGUMENTS` — optional, space-separated: `[cpuCount] [projectName] [--remote-cache]`. Number token
→ `cpuCount`. Non-number, non-flag token → `projectName`. `--remote-cache` flag → opt back into the
remote cache by dropping the remote-cache-off prefix. Default `cpuCount` = cores - 4 (min 1);
count cores with `getconf _NPROCESSORS_ONLN` (`nproc` is GNU-only).
Default project scope = affected. Default remote-cache state = off (see Steps).

## Workspace

Run nx commands from wherever `nx.json` lives in this repo (commonly the root; in some repos a
subdirectory).

## Setup (before step 1)

Keep the Nx daemon warm so the project graph is reused across targets:

```bash
NX_DAEMON=true npx nx daemon --start >/dev/null 2>&1 || true
```

### Affected base (skip when `$projectName` was passed)

`nx affected` diffs against the *local* default branch, which is often stale or missing. Resolve
the remote-tracking ref once and write it literally into every `affected`, `format:write` and
`show projects --affected` command below as `--base=$base` (each call is a fresh shell, see Steps):

```bash
base=${NX_BASE:-$(node -p 'const j=require("./nx.json"); j.defaultBase ?? j.affected?.defaultBase ?? "main"' 2>/dev/null || echo main)}
base=${base#remotes/}; [[ $base == */* ]] || base="origin/$base"
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=15' git fetch --quiet "${base%%/*}" "${base#*/}" || echo "fetch failed: base may be stale"
git rev-parse --verify --quiet "$base" >/dev/null && echo "base=$base" || echo "no such ref: omit --base"
```

- Omit `--base` when the ref is missing (Nx falls back to `defaultBase`) or `NX_BASE` is set (Nx
  reads it itself; the fetch still runs).
- **Never pass `--head`.** With both flags Nx diffs two commits and ignores uncommitted and
  untracked files, so an agent's unstaged edits vanish and every check passes vacuously.
- A failed fetch is not a failure: continue on the current ref, flag "base may be stale" in the
  final report, and never retry outside the sandbox for it.

Why: [affected-base-rationale.md](affected-base-rationale.md).

## Fix rule

- Apply only mechanical/unambiguous fixes: lint auto-fix output, missing imports/types, obvious type
  errors, test expectations that mirror a clear code change.
- Never guess on anything judgment-laden: test failure that could be a real bug vs. an outdated
  assertion, errors pointing at unrelated areas, pre-existing failures unrelated to recent work,
  anything where multiple plausible fixes exist. Running forked, you can't ask mid-run: leave such
  failures unfixed and carry them, with your analysis, into the final report.
- Keep changes minimal and scoped to the failure. No drive-by refactors.
- After fixing, re-run the check. Repeat until clean or only judgment-laden failures remain.

## Affected scope — sanity-check before build/test

Affected runs can balloon. Before steps 3–4, check scope with the graph-only
`npx nx show projects --affected --base=$base` (fast, no build):

- **Sandbox `.env` false positives.** The sandbox denies reading `**/.env`; `nx affected` hashes
  changed files, so an unreadable `.env` reads as *changed* and marks its project affected. Repos
  with `.env`-bearing apps (e.g. `apps/*-api`) thus drag those into every affected run and build
  them for nothing. Tell-tale: `git status` prints `<path>/.env: Operation not permitted` for
  exactly those projects. Fix: rerun the nx commands with the sandbox disabled so `.env` reads
  succeed, or `--exclude` those projects.
- **Large fan-out.** If the set is large (e.g. a widely-shared lib change rippling across the
  workspace), don't build the world unprompted: skip steps 3–4 and report the project count and
  scope in the final report so the user can re-run with an explicit scope.

## Steps

**Scope is mandatory — never narrow it yourself.** With no `$projectName` argument, *every* target
runs at full scope — `nx affected` for lint/test/build, whole-changeset `format:write`. The
single-project forms in the steps below apply **only** when the user explicitly passed
`$projectName`. Never substitute `nx run <proj>:<target>`, `nx <target> <changedLib>`, or
file-scoped `format --files` for the affected sweep: that skips every other affected project —
exactly where a shared-lib change regresses (a dependent project whose tests import the changed
lib). And never add `--skip-nx-cache` (see below).

Always prefix each nx command with **both** remote-cache-off env vars inline
(`NX_POWERPACK_CACHE_MODE=no-cache` for Powerpack remote caches, `NX_NO_CLOUD=true` for Nx Cloud).
They're additive and the unrecognized one is a no-op, so this is safe regardless of which
remote-cache backend (if any) the repo uses.

The invariant: **remote cache always off (unless the user passed `--remote-cache`), local cache
always on** — always disable, never autodetect (a passing shell-side auth check doesn't predict the
in-process credential chain). Why: [remote-cache-rationale.md](remote-cache-rationale.md).

If the user explicitly passed `--remote-cache`, drop both prefixes. Expect pipeline hits on `build`
only: `--fix` and `--maxWorkers=1` are hashed overrides, so lint and test entries never match a
pipeline run without them — keep the flags regardless.

**Always keep the local cache on.** The env vars above disable only the _remote_ read-through cache;
the local Nx cache must stay enabled so unchanged targets are replayed instead of re-run. Do **not**
add `--skip-nx-cache` (nor `NX_SKIP_NX_CACHE=true`) to any command — it bypasses the local cache
too, making every run slower for no benefit. The only valid reason to pass `--skip-nx-cache` is a
specific, stated need to bypass the local cache — e.g. investigating a failure you suspect is caused
by a stale cache entry. In that case, scope it to the single command under investigation and say
why; never use it as the default.

Write both env vars literally at the start of each nx command, exactly as in the steps below. Do
**not** rely on `export` — each Bash tool call is a fresh shell, so exports do not carry across
calls (true for any nx env var). Never stash the prefix in a shell variable
(`NX_OFF="…"; $NX_OFF npx nx …` fails with "command not found": expanded variables are not parsed
as assignments).

1. Lint — `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx affected -t lint --base=$base --parallel=$cpuCount --fix`
   (or `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx lint $projectName --fix`).
2. Format — `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx format:write --base=$base`
3. Test — `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx affected -t test --base=$base --parallel=$cpuCount --maxWorkers=1`
   (or `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx test $projectName`).
4. Build — `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx affected -t build --base=$base --configuration=production --parallel=$cpuCount`
   (or `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx build $projectName --configuration=production --parallel=$cpuCount`).

Apply the fix rule on any failure in steps 1–4.

`--configuration=production` mirrors pipelines and surfaces production-only failures (AOT, budgets);
a project without that configuration falls back to its default, so it is safe workspace-wide.

### `--maxWorkers=1` on the test step

`--parallel` caps concurrent *projects*; each test task still fans out to ~all cores internally, so
without this the cores oversubscribe (CPU pegs at 100%). `--maxWorkers=1` pins each task to one
worker → `--parallel=$cpuCount` ≈ `$cpuCount` cores. Both Vitest and Jest accept the flag.

- **Test step only.** Forwarding `--maxWorkers` to lint (ESLint) or build (esbuild) fails as an
  unknown option.
- **Affected/run-many only, not single-project.** With one project there's no project-level fan-out,
  so capping to one worker just serializes it — let a single project use all cores.

Same reason, `--parallel` is dropped from single-project **lint** and **test** (one task each — no
fan-out). It stays on single-project **build**, because `build` has `dependsOn: ["^build"]`, so
building one project fans out across its whole dependency chain.

## Flaky tests — retry once to classify

A failed `test` target may be flaky, not a real break. On a test failure, re-run that one target
once: `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx test <project>`. If it then
passes, or Nx prints `NX detected a flaky task`, it's flaky — don't try to "fix" it; record it as
a flaky `project:target` for the report. If it fails the same way again, treat it as real under
the Fix rule.

## Final report (mandatory)

This skill runs in a forked context, so its final message is the only channel back to the caller.
End by listing the affected base used (or omitted / possibly stale), then per target (lint /
format / test / build): clean, skipped (with the reason — for large fan-out, the project count and
scope), or each failing `project:target` with its cause, plus any flaky `project:target`. Never
report a bare "checks passed" — an unlisted failure or skipped target reads as green and the caller
can't act on it.
