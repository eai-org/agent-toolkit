---
name: run-nx-checks
description: Run nx format, lint, test, and build on affected or specified projects, then fix unambiguous failures
context: fork
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.1"
---

# Run Nx Checks

Run format, lint, test, build. Fix unambiguous failures. Ask on anything judgment-laden.

## Arguments

`$ARGUMENTS` — optional, space-separated: `[cpuCount] [projectName] [--remote-cache]`.
Number token → `cpuCount`. Non-number, non-flag token → `projectName`. `--remote-cache` flag → opt back into the remote cache by dropping the remote-cache-off prefix.
Default `cpuCount` = `nproc - 4` (min 1). Default project scope = affected. Default remote-cache state = off (see "Why the remote cache is off by default" below).

## Workspace

Run nx commands from wherever `nx.json` lives in this repo (commonly the root; in some repos a subdirectory).

## Setup (before step 1)

Keep the Nx daemon warm so the project graph is reused across targets:

```bash
NX_DAEMON=true npx nx daemon --start >/dev/null 2>&1 || true
```

Do **not** rely on `export` for the remote-cache-off env vars (or any other nx env var) — each Bash tool call is a fresh shell, so exports do not carry across calls. Always inline env vars on the command line of each nx invocation (see Steps below).

## Fix rule (applies to lint, test, build)

- Apply only mechanical/unambiguous fixes: lint auto-fix output, missing imports/types, obvious type errors, test expectations that mirror a clear code change.
- Ask the user — don't guess — for anything judgment-laden: test failure that could be a real bug vs. an outdated assertion, errors pointing at unrelated areas, pre-existing failures unrelated to recent work, anything where multiple plausible fixes exist.
- Keep changes minimal and scoped to the failure. No drive-by refactors.
- After fixing, re-run the check. Repeat until clean or you need to ask.

## Steps

Always prefix each nx command with **both** remote-cache-off env vars inline. They're additive and the unrecognized one is a no-op, so this is safe regardless of which remote-cache backend (if any) the repo uses:

- `NX_POWERPACK_CACHE_MODE=no-cache` — disables Nx Powerpack remote caches (`@nx/azure-cache`, `@nx/s3-cache`, `@nx/gcs-cache` — all read the same env var via shared `powerpack-utils`).
- `NX_NO_CLOUD=true` — disables Nx Cloud's remote read-through cache.

If the user explicitly passed `--remote-cache`, drop both prefixes.

Define a shell variable once per Bash call to keep commands readable. Each step is a separate Bash invocation, so re-define it each time:

```bash
NX_OFF="NX_POWERPACK_CACHE_MODE=no-cache NX_NO_CLOUD=true"
```

1. Format — `$NX_OFF npx nx format:write`
2. Lint — `$NX_OFF npx nx affected -t lint --parallel=$cpuCount --fix` (or `$NX_OFF npx nx lint $projectName --parallel=$cpuCount --fix`).
3. Test — `$NX_OFF npx nx affected -t test --parallel=$cpuCount` (or `$NX_OFF npx nx test $projectName --parallel=$cpuCount`).
4. Build — `$NX_OFF npx nx affected -t build --parallel=$cpuCount` (or `$NX_OFF npx nx build $projectName --parallel=$cpuCount`).

Apply the fix rule on any failure in steps 2–4.

## Why the remote cache is off by default

Local affected runs gain little from a remote read-through cache, and inside the Claude Code sandbox the auth side effects of the cloud backends are actively harmful. Two families of remote-cache backends exist for Nx, and the skill disables both because we can't always tell from outside which (if any) is in use:

- **Nx Powerpack remote caches** (`@nx/azure-cache`, `@nx/s3-cache`, `@nx/gcs-cache`). All three are built on the shared `powerpack-utils` and read `NX_POWERPACK_CACHE_MODE` — setting it to `no-cache` short-circuits both reads and writes, so the cloud SDK's credential chain never starts.
- **Nx Cloud** (the SaaS read-through cache; gated by `NX_NO_CLOUD=true`).

What actually goes wrong in the sandbox (observed with `@nx/azure-cache`, but the pattern generalises to the other Powerpack backends and any code path that calls `DefaultAzureCredential` / `DefaultAwsCredentialProvider` / etc.):

- The cloud SDK probes a chain of credential providers (e.g. Azure: Environment → ManagedIdentity → VSCode → PowerShell → AzDev CLI → `az`) inside the node process. Each unavailable provider costs multiple seconds before falling through.
- The `az` fallback tries to write to `~/.azure/commands/*.log`, which the sandbox denies (`PermissionError: Operation not permitted`), causing further failures down the chain.
- A shell-side check like `az account show` returning success does **not** mean the in-process credential chain will succeed — they're different code paths. So an autodetect based on `az` status is unreliable. Always disable, don't autodetect.

Net result without the prefix: every nx target hangs for ~5–10s of credential probing per invocation, four times over (format / lint / test / build), for no benefit. Inlining both env vars short-circuits whichever backend is actually in use; the unused one is a harmless no-op.

If the user explicitly wants the remote cache for this run, accept `--remote-cache` and omit both prefixes.
