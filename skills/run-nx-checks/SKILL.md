---
name: run-nx-checks
description: Run nx format, lint, typecheck, test, and build on affected or specified projects, then fix unambiguous failures
context: fork
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
license: MIT
metadata:
  version: "1.9"
---

# Run Nx Checks

Run format, lint, typecheck, test, build. Fix unambiguous failures. Report anything judgment-laden
and every file you changed.

## Arguments

`$ARGUMENTS` — optional, space-separated: `[cpuCount] [projectName] [--remote-cache]`. Number
token → `cpuCount`. Non-number, non-flag token → `projectName`. `--remote-cache` flag → opt back
into the remote cache by dropping the remote-cache-off prefix. Default `cpuCount` = cores - 4
(min 1); count cores with `node -p 'os.cpus().length'`.
Default project scope = affected. Default remote-cache state = off (see Steps).

`$base`, `$cpuCount` and `$projectName` in the commands below are placeholders: substitute their
values (a fresh shell per Bash tool call holds none of them).

## Workspace

Run nx commands from wherever `nx.json` lives in this repo (commonly the root; in some repos a
subdirectory).

## Setup (before step 1)

Keep the Nx daemon warm so the project graph is reused across targets:

```bash
NX_DAEMON=true npx nx daemon --start >/dev/null 2>&1 || true
```

Snapshot the dirty files, so the final report can name every file the run changes (`hash-object`
without `-w` writes nothing):

```bash
git ls-files -z -mo --exclude-standard | while IFS= read -r -d '' f; do echo "$(git hash-object "$f" 2>/dev/null) $f"; done > "${TMPDIR:-/tmp}/nx-checks-before.txt"
```

### Affected base

`nx affected` and `format:write` diff against the *local* default branch, which is often stale or
missing. `$projectName` replaces only the `affected` commands, so resolve the base in both modes.
`NX_BASE` set: skip this section; Nx reads it and a deliberate env setting wins. Otherwise resolve
the remote-tracking ref once and substitute the printed ref for `$base` in every `affected`,
`format:write` and `show projects --affected` command below:

```bash
base=$(node -p 'const j=require("./nx.json"); j.defaultBase ?? j.affected?.defaultBase ?? "main"' 2>/dev/null || echo main)
base=${base#remotes/}; [[ $base == */* ]] || base="origin/$base"
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=15' git fetch --quiet "${base%%/*}" "${base#*/}" || echo "fetch failed: base may be stale"
git rev-parse --verify --quiet "$base" >/dev/null && echo "base=$base" || echo "no such ref: omit --base"
```

- Omit `--base` when the ref is missing (Nx falls back to `defaultBase`).
- **Never pass `--head`.** With both flags Nx diffs two commits and ignores uncommitted and
  untracked files, so an agent's unstaged edits vanish and every check passes vacuously.
- A failed fetch is not a failure: continue on the current ref, flag "base may be stale" in the
  final report, and never retry outside the sandbox for it.

Why: [affected-base-rationale.md](affected-base-rationale.md).

## Fix rule

- Apply only mechanical/unambiguous fixes: lint auto-fix output, missing imports/types, obvious type
  errors, test expectations that mirror a clear code change. An assertion or snapshot update is
  mechanical only when the failing expectation names a value the working-tree diff changed on
  purpose; edit that expectation by hand. Never pass `-u`/`--updateSnapshot` to a target.
- Never guess on anything judgment-laden: test failure that could be a real bug vs. an outdated
  assertion, errors pointing at unrelated areas, pre-existing failures unrelated to recent work,
  anything where multiple plausible fixes exist. Running forked, you can't ask mid-run: leave such
  failures unfixed and carry them, with your analysis, into the final report.
- Keep changes minimal and scoped to the failure. No drive-by refactors.
- After fixing, re-run the same step command; the local cache replays the untouched projects.
  Repeat until clean or only judgment-laden failures remain.

## Affected scope — sanity-check before step 1

Affected runs only (no `$projectName`); they can balloon. Before step 1, check scope with the
graph-only `npx nx show projects --affected --base=$base` (fast, no build):

- **Sandbox `.env` false positives.** The sandbox denies reading `**/.env`; `nx affected` hashes
  changed files, so an unreadable `.env` reads as *changed* and marks its project affected. Repos
  with `.env`-bearing apps (e.g. `apps/*-api`) thus drag those into every affected run and build
  them for nothing. Tell-tale: run `git status`; it prints `<path>/.env: Operation not permitted`
  for exactly those projects. Fix: add `--exclude=<their project names>` to every `affected`
  command (`format:write` takes none) and list them as excluded in the final report, naming any
  real edits they hold; the user can re-run outside the sandbox to include them.
- **Large fan-out.** Large = more than half of `npx nx show projects | wc -l` or more than 20
  projects, whichever is lower (e.g. a widely-shared lib change rippling across the workspace).
  Don't build the world unprompted: skip steps 3–5 and report the project count and list in the
  final report so the user can re-run with `$projectName`.

## Steps

**Scope is mandatory — never narrow it yourself.** With no `$projectName` argument, *every* target
runs at full scope — `nx affected` for lint/typecheck/test/build, whole-changeset `format:write`.
The single-project forms in the steps below apply **only** when the user explicitly passed
`$projectName`. Never substitute `nx run <proj>:<target>`, `nx <target> <changedLib>`, or
file-scoped `format --files` for the affected sweep: that skips every other affected project —
exactly where a shared-lib change regresses (a dependent project whose tests import the changed
lib).

Always prefix each task-running nx command (steps 1–5 and the flaky retry; `daemon` and
`show projects` run no tasks) with the remote-cache-off env vars inline:
`NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache`.
`NX_SKIP_REMOTE_CACHE` turns off every remote cache on Nx 20+; the other two cover Nx 19 and
Powerpack. Unknown vars are no-ops, so the prefix is safe whatever remote-cache backend (if any)
the repo uses.

The invariant: **remote cache always off (unless the user passed `--remote-cache`), local cache
always on** — always disable, never autodetect (a passing shell-side auth check doesn't predict
the in-process credential chain). Why: [remote-cache-rationale.md](remote-cache-rationale.md).

If the user explicitly passed `--remote-cache`, drop the prefix. Expect pipeline hits on `build`
only: `--fix` and `--maxWorkers=1` are hashed overrides, so lint and test entries never match a
pipeline run without them — keep the flags regardless.

**Always keep the local cache on.** The env vars above disable only the _remote_ read-through
cache; the local Nx cache must stay enabled so unchanged targets are replayed instead of re-run.
Do **not** add `--skip-nx-cache` (nor `NX_SKIP_NX_CACHE=true`) to any command — it bypasses the
local cache too, making every run slower for no benefit. The only valid reason to pass
`--skip-nx-cache` is a specific, stated need to bypass the local cache — e.g. investigating a
failure you suspect is caused by a stale cache entry. In that case, scope it to the single command
under investigation and say why; never use it as the default.

Write the env vars literally at the start of each such command, exactly as in the steps below. Do
**not** rely on `export` — each Bash tool call is a fresh shell, so exports do not carry across
calls (true for any nx env var). Never stash the prefix in a shell variable
(`NX_OFF="…"; $NX_OFF npx nx …` fails with "command not found": expanded variables are not parsed
as assignments).

1. Lint — `NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache npx nx affected -t lint --base=$base --parallel=$cpuCount --fix`
   (or `NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache npx nx lint $projectName --fix`).
2. Format — `NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache npx nx format:write --base=$base`
   (both modes).
3. Typecheck — `NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache npx nx affected -t typecheck --base=$base --parallel=$cpuCount`
   (or `NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache npx nx typecheck $projectName`).
   Without the target, `affected` runs nothing and exits 0 and the single-project form errors with
   "cannot find configuration": report typecheck as n/a, never as failing.
4. Test — `NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache npx nx affected -t test --base=$base --parallel=$cpuCount --maxWorkers=1`
   (or `NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache npx nx test $projectName`).
5. Build — `NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache npx nx affected -t build --base=$base --configuration=production --parallel=$cpuCount`
   (or `NX_SKIP_REMOTE_CACHE=true NX_NO_CLOUD=true NX_POWERPACK_CACHE_MODE=no-cache npx nx build $projectName --configuration=production --parallel=$cpuCount`).

Apply the fix rule on any failure in steps 1–5 (a test failure: retry once first, see Flaky
tests). A failure left unfixed never stops the run: carry on with the next step.

### Flags per target

Why `--configuration=production` and `--maxWorkers=1`: [flags-rationale.md](flags-rationale.md).

- **`--maxWorkers=1` on the test step only.** Forwarding it to lint (ESLint) or build (esbuild)
  fails as an unknown option.
- **Affected/run-many only, not single-project.** With one project there's no project-level
  fan-out, so capping to one worker just serializes it — let a single project use all cores.
- Same reason, `--parallel` is dropped from single-project **lint**, **typecheck** and **test**
  (one task each — no fan-out). It stays on single-project **build**, because `build` has
  `dependsOn: ["^build"]`, so building one project fans out across its whole dependency chain.

## Flaky tests — retry once to classify

A failed `test` target may be flaky, not a real break. On a test failure, re-run that one target
once in step 4's single-project form, prefixed like the steps (`… npx nx test <project>`). If it
then passes (or, with Nx Cloud on, Nx prints `NX detected a flaky task`), it's flaky — don't try
to "fix" it; record it as a flaky `project:target` for the report. If it fails the same way again,
treat it as real under the Fix rule.

## Final report (mandatory)

This skill runs in a forked context, so its final message is the only channel back to the caller.
End with:

- the affected base used (or omitted / possibly stale);
- per target (lint / format / typecheck / test / build): clean, n/a, skipped (with the reason —
  for large fan-out, the project count and list; for `.env` false positives, the excluded
  projects), or each failing `project:target` with its cause, plus any flaky `project:target`;
- every file the run changed: hand-fixed (from your own edits — file plus one line on what and
  why) and tool-applied (lint `--fix`, `format:write` — every other file that differs or is new
  when the Setup snapshot command is re-run into `${TMPDIR:-/tmp}/nx-checks-after.txt` and the
  two files are diffed).

Never report a bare "checks passed": an unlisted failure, skipped target or unmentioned edit reads
as green and the caller can't act on it.
