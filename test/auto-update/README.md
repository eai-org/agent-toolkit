# auto-update harness

Covers [`lib/auto-update.sh`](../../lib/auto-update.sh) and the auto-update wiring in both
installers: the daily throttle, the lock, the refuse checks, the replay, the feedback, and how the
installers register or remove the hook in `settings.json`.

```sh
bash test/auto-update/run.sh            # every case
bash test/auto-update/run.sh dirty      # named cases only
```

Each case builds its own remote, clone and `HOME` under `runs/<timestamp>/<case>/` and leaves them
there to inspect; `runs/` is gitignored. The clone under test is a snapshot of the working tree, so
there is no need to commit before running.

The cases that compare the three settings.json engines link the real `node` and `jq` into the
case's own `bin`. Neither is guaranteed to be on the harness path, so a leg whose binary is missing
is skipped with a printed `(no jq available, skipping the jq leg)` line — the same run asserts less
on a machine without them.

The harness itself needs a working `python3`: it reads `settings.json` and hook output through
it, resolved once at startup and called by absolute path so the broken-interpreter shims the
cases stage cannot reach it. Without a usable one, the run refuses to start rather than producing
empty comparisons — unlike `node` and `jq` above, which are optional and only skip a leg.

It needs write access to the `.git` directories it creates under `runs/` — a sandbox that blocks
those will fail at the first case.

Windows behaviour is not covered.
