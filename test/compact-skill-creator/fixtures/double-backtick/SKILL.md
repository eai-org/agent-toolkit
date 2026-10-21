---
name: double-backtick
description: A fixture skill with double-backtick code spans holding a link template and an overrun.
license: MIT
metadata:
  version: "1.0"
---

# Double backtick

A double-backtick span is a template, not a link: ``[example](missing.md)``.

A command that holds a backtick stays on one line past the limit: ``git log --format='%h `%s`' --no-merges``
