# Why `--configuration=production` and `--maxWorkers=1`

- **`--configuration=production`** mirrors pipelines and surfaces production-only failures (AOT,
  budgets); a project without that configuration falls back to its default, so it is safe
  workspace-wide.
- **`--maxWorkers=1`.** `--parallel` caps concurrent *projects*; each test task still fans out to
  ~all cores internally, so without it the cores oversubscribe (CPU pegs at 100%). Pinning each
  task to one worker makes `--parallel=$cpuCount` ≈ `$cpuCount` cores. Both Vitest and Jest accept
  the flag.
