---
name: run-nx-checks
description: Run nx format, lint, test, and build on affected or specified projects, then fix unambiguous failures
context: fork
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.5"
---

# Run Nx Checks

Run format, lint, test, build. Fix unambiguous failures. Report anything judgment-laden.

## Arguments

`$ARGUMENTS` — optional, space-separated: `[cpuCount] [projectName] [--remote-cache]`. Number token
→ `cpuCount`. Non-number, non-flag token → `projectName`. `--remote-cache` flag → opt back into the
remote cache by dropping the remote-cache-off prefix. Default `cpuCount` = cores - 4 (min 1);
count cores with `getconf _NPROCESSORS_ONLN` (`nproc` is GNU-only).
Default project scope = affected. Default remote-cache state = off (see "Why the remote cache is off
by default" below).

## Workspace

Run nx commands from wherever `nx.json` lives in this repo (commonly the root; in some repos a
subdirectory).

## Setup (before step 1)

Keep the Nx daemon warm so the project graph is reused across targets:

```bash
NX_DAEMON=true npx nx daemon --start >/dev/null 2>&1 || true
```

Do **not** rely on `export` for the remote-cache-off env vars (or any other nx env var) — each Bash
tool call is a fresh shell, so exports do not carry across calls. Always inline env vars on the
command line of each nx invocation (see Steps below).

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
`npx nx show projects --affected` (fast, no build):

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

Always prefix each nx command with **both** remote-cache-off env vars inline. They're additive and
the unrecognized one is a no-op, so this is safe regardless of which remote-cache backend (if any)
the repo uses:

- `NX_POWERPACK_CACHE_MODE=no-cache` — disables Nx Powerpack remote caches (`@nx/azure-cache`,
  `@nx/s3-cache`, `@nx/gcs-cache` — all read the same env var via shared `powerpack-utils`).
- `NX_NO_CLOUD=true` — disables Nx Cloud's remote read-through cache.

If the user explicitly passed `--remote-cache`, drop both prefixes.

**Always keep the local cache on.** The env vars above disable only the _remote_ read-through cache;
the local Nx cache must stay enabled so unchanged targets are replayed instead of re-run. Do **not**
add `--skip-nx-cache` (nor `NX_SKIP_NX_CACHE=true`) to any command — it bypasses the local cache
too, making every run slower for no benefit. The only valid reason to pass `--skip-nx-cache` is a
specific, stated need to bypass the local cache — e.g. investigating a failure you suspect is caused
by a stale cache entry. In that case, scope it to the single command under investigation and say
why; never use it as the default.

Write both env vars literally at the start of each nx command, exactly as in the steps below.
Never stash the prefix in a shell variable (`NX_OFF="…"; $NX_OFF npx nx …` fails with "command not
found": expanded variables are not parsed as assignments).

1. Lint — `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx affected -t lint --parallel=$cpuCount --fix`
   (or `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx lint $projectName --fix`).
2. Format — `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx format:write`
3. Test — `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx affected -t test --parallel=$cpuCount --maxWorkers=1`
   (or `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx test $projectName`).
4. Build — `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx affected -t build --parallel=$cpuCount`
   (or `NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true npx nx build $projectName --parallel=$cpuCount`).

Apply the fix rule on any failure in steps 1–4.

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
End by listing, per target (lint / format / test / build): clean, skipped (with the reason — for
large fan-out, the project count and scope), or each failing `project:target` with its cause, plus
any flaky `project:target`. Never report a bare "checks passed" — an unlisted failure or skipped
target reads as green and the caller can't act on it.

## Why the remote cache is off by default

Local affected runs gain little from a remote read-through cache, and inside the sandbox
the auth side effects of the cloud backends are actively harmful. Two families of remote-cache
backends exist for Nx, and the skill disables both because we can't always tell from outside which
(if any) is in use:

- **Nx Powerpack remote caches** (`@nx/azure-cache`, `@nx/s3-cache`, `@nx/gcs-cache`). All three are
  built on the shared `powerpack-utils` and read `NX_POWERPACK_CACHE_MODE` — setting it to
  `no-cache` short-circuits both reads and writes, so the cloud SDK's credential chain never starts.
- **Nx Cloud** (the SaaS read-through cache; gated by `NX_NO_CLOUD=true`).

What actually goes wrong in the sandbox (observed with `@nx/azure-cache`, but the pattern
generalises to the other Powerpack backends and any code path that calls `DefaultAzureCredential` /
`DefaultAwsCredentialProvider` / etc.):

- The cloud SDK probes a chain of credential providers (e.g. Azure: Environment → ManagedIdentity →
  VSCode → PowerShell → AzDev CLI → `az`) inside the node process. Each unavailable provider costs
  multiple seconds before falling through.
- The `az` fallback tries to write to `~/.azure/commands/*.log`, which the sandbox denies
  (`PermissionError: Operation not permitted`), causing further failures down the chain.
- A shell-side check like `az account show` returning success does **not** mean the in-process
  credential chain will succeed — they're different code paths. So an autodetect based on `az`
  status is unreliable. Always disable, don't autodetect.

Net result without the prefix: every nx target hangs for ~5–10s of credential probing per
invocation, four times over (format / lint / test / build), for no benefit. Inlining both env vars
short-circuits whichever backend is actually in use; the unused one is a harmless no-op.

If the user explicitly wants the remote cache for this run, accept `--remote-cache` and omit both
prefixes.
