# Why the remote cache is off by default

Local affected runs gain little from a remote read-through cache, and inside the sandbox the auth
side effects of the cloud backends are actively harmful. Since we can't always tell from outside
which backend (if any) is in use, the skill disables them all, always, with three env vars:

- `NX_SKIP_REMOTE_CACHE=true` — Nx 20+ reads it before loading any remote-cache plugin
  (`tasks-runner/cache.ts`), so it covers Powerpack (`@nx/azure-cache`, `@nx/s3-cache`,
  `@nx/gcs-cache`), `@nx/shared-fs-cache` and the self-hosted HTTP cache alike.
- `NX_NO_CLOUD=true` — gates Nx Cloud (the SaaS read-through cache) on every Nx version.
- `NX_POWERPACK_CACHE_MODE=no-cache` — the Powerpack backends' own switch (shared
  `powerpack-utils`), needed on Nx 19, which does not know `NX_SKIP_REMOTE_CACHE`. It
  short-circuits both reads and writes, so the cloud SDK's credential chain never starts.

Unknown vars are no-ops, so the full prefix is safe on any version and backend.

What actually goes wrong in the sandbox (observed with `@nx/azure-cache`, but the pattern
generalises to the other Powerpack backends and any code path that calls `DefaultAzureCredential`
/ `DefaultAwsCredentialProvider` / etc.):

- The cloud SDK probes a chain of credential providers (e.g. Azure: Environment → ManagedIdentity
  → VSCode → PowerShell → AzDev CLI → `az`) inside the node process. Each unavailable provider
  costs multiple seconds before falling through.
- The `az` fallback tries to write to `~/.azure/commands/*.log`, which the sandbox denies
  (`PermissionError: Operation not permitted`), causing further failures down the chain.
- A shell-side check like `az account show` returning success does **not** mean the in-process
  credential chain will succeed — they're different code paths. So an autodetect based on `az`
  status is unreliable. Always disable, don't autodetect.

Net result without the prefix: every nx target hangs for ~5–10s of credential probing per
invocation, five times over (lint / format / typecheck / test / build), for no benefit.
