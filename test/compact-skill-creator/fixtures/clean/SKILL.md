---
name: clean
description: A fixture skill whose files pass every check, including the allowed overruns below.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "1.0"
---

# Clean

A prose line that stays under the limit, with a working link to [reference.md](reference.md#top).

Ends with a command that stays on one line even past the limit, as the conventions allow: `claude --name create-plan-<slug> "/create-implementation-plan <path>.REQUIREMENTS.md"`

Counted in characters — six em dashes — push this line — past one hundred bytes — while — shortxx.

````
a four-backtick fence holds an inner ``` line and a line far over the limit that the check must still skip
```
````

A source link is never wrapped either: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices

| column | a table row is never wrapped, however long it grows, because wrapping would break the table |
| --- | --- |

```
a fenced code block holds a line that would be far over the limit in prose, and the check must skip it entirely
```
