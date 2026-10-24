# Orders service — agent guide

- Money is always `int` cents. Never `float` in pricing or totals.
- Library code never calls `print()`; use `orders.log.info` / `orders.log.warn`.
- Every public function in `orders/` has a one-line docstring.
- Tests live in `tests/`, one `test_<module>.py` per module; every new public behaviour gets a test
  that fails when the behaviour breaks.
- Repository methods never raise on a missing record: they return `None` or `False`.
- `README.md` documents every user-facing rule (limits, windows, codes); update it in the same
  change.
