---
name: split-plan-tasks
description: Split a plan into small, individually reviewable tasks grouped into PR-sized batches, appended as a task section at the end of the plan file.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "0.1"
---

# Split plan into tasks

Append a task breakdown to a plan so the work lands in small increments — one task, then a review,
a correction pass, a commit — instead of one sweep. Authoring only: executing the tasks is a later,
separate session.

Invocation: `/split-plan-tasks <plan-path>`

## Read the plan

Ambiguous or missing path → ask. A plan with numbered steps and an acceptance-criteria checklist
splits best; any plan markdown works — reference tasks to headings when steps aren't numbered, and
drop the AC line when there is no such checklist.

A plan already carrying a task section → **stop and ask** which the user wants: replace it, add a
second one beside it, or carry the ticked tasks forward and reformulate only the remaining work.

Done when the plan is read and, where a section already existed, the user has chosen.

## Work out the split

- **Task** — the smallest chunk that leaves the project building and its tests passing, so it can be
  reviewed and committed on its own. Steps that only make sense together are one task, never two.
- **Group** — one PR: independently mergeable, delivering something coherent. Order the groups and
  state each one's dependency on earlier groups.
- Respect the plan's ordering: a task never precedes what it depends on.
- **Front-load a hands-on slice.** Among dependency-legal orderings, prefer the one whose first
  group leaves the app exercisable by hand — a screen to click where the plan touches a UI, else a
  command to run or an endpoint to hit — accepting a larger first group when that's what makes the
  slice whole, never scaffolding the plan doesn't call for. When nothing early gets there, say so
  when presenting.
- Both ways: every plan step and every acceptance criterion lands in exactly one task, and no task
  invents work the plan doesn't call for.

Present the whole breakdown with the obvious calls already decided, and walk only the genuinely
doubtful boundaries as individual questions, each carrying your recommendation. One approval gate
before writing anything.

Done when every step and criterion is placed, the first group is exercisable or you've said why
not, and the user has approved the breakdown.

## Append the section

At the end of the plan file — the only edit made:

```markdown
## Tasks

### Group 1 — <what this PR delivers>

*Depends on* nothing
*Try it* <what to open or run to exercise the app>

- [ ] **1.1 <short imperative>** — steps 2–3
  - *Done when* <what to run or look at to confirm it landed>
  - *Satisfies* AC-1, AC-4
  - *Commit* `<suggested subject>`
```

*Try it* goes only on the first group that leaves the app exercisable.

Done when every task from the approved breakdown is in the file.

## Close

State the plan's project-relative path and the tally (tasks, groups). Then hand off as a single
copy-pasteable launch command — session name and prompt combined, in the launch syntax of the agent
tool in use (vendor-agnostic — `claude` below is only the example), naming the session
`execute-tasks-<slug>` after the plan's slug:

```
claude --name execute-tasks-<slug> "/execute-plan-tasks <plan-path> 1.1"
```

Then offer the alternative — clearing the current session instead (vendor-agnostic — `/clear` is
only the example):

OR /clear and run:

```
/execute-plan-tasks <plan-path> 1.1
```

Done when the path, the tally, and both commands are printed.

## Boundaries

- The appended section is the only edit: never rewrite the plan's existing content, never touch
  source files.
- No implementation — the breakdown is the output.
