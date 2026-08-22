---
name: execute-plan-tasks
description: Execute one task from a plan's task breakdown, verify it, tick it off, and hand back for review before the next one.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "0.1"
---

# Execute plan tasks

One task per run — implement it, verify it, tick it, stop. The review between tasks is the point;
never carry on into the next.

Invocation: `/execute-plan-tasks <plan-path> [task-id]`

## Pick the task

Read the plan whole — summary, conventions and overrides, the steps the task cites, acceptance
criteria — then its `## Tasks` section. Ambiguous or missing plan path → ask. Several task sections
→ ask which one this run works from. No task section → stop and point at `/split-plan-tasks`.

`task-id` given → that task; none → the first unticked one in order. A range or a whole group → run
its first task only, saying the rest need their own runs; a task already ticked → say so and ask
whether to redo it. Its dependencies — earlier tasks in its group, plus every group its *Depends
on* names — must be ticked; any that isn't → name it and ask before proceeding.

Done when the chosen task, its steps, its acceptance criteria and its dependency state are stated.

## Execute

- **Scope is the task's steps, nothing else**: no work belonging to a later task, no drive-by
  refactors. Work the plan calls for that no task covers → report it, don't absorb it.
- The plan's conventions and overrides bind every task, this one included.
- **Never guess.** What the code settles, settle by reading it; what it doesn't goes to the user as
  one question carrying your recommendation. Append each settled deviation from the plan, and its
  why, as one line to the decisions log beside the plan (`<slug>.DECISIONS.md`), creating it if
  absent.
- Blocked outright — a step the codebase contradicts, an unmet prerequisite — → stop, leave the
  task unticked, report what blocks it.

Done when every step of the task is implemented, or its blocker reported.

## Verify

Run the task's *Done when* check, then the validation the project's governing docs name — failing
that, its toolchain's lint, tests and build; nothing runnable → say so rather than invent a
command. Fix what this task broke; a failure that predates it or lands outside its scope is
reported, never fixed silently.

Done when both pass, or every remaining failure is reported with why it stands.

## Close

Tick the task `- [ ]` → `- [x]`, plus each acceptance criterion it *Satisfies* whose every
satisfying task is now ticked — the plan's only edits, made once verification passed; name the ACs
still partly open. Then print the files touched, any deviation logged, and the task's *Commit*
subject (absent → propose one in the repo's style) to commit once the change is reviewed. Finally
hand off the next unticked task as a single copy-pasteable launch command — session name and prompt
combined, in the launch syntax of the agent tool in use (vendor-agnostic — `claude` below is only
the example):

```
claude --name execute-tasks-<slug> "/execute-plan-tasks <plan-path> <next-task-id>"
```

Then offer the alternative — clearing the current session instead (vendor-agnostic — `/clear` is
only the example):

OR /clear and run:

```
/execute-plan-tasks <plan-path> <next-task-id>
```

When the finished task completes its group, say so first — the group is a PR — and point at the
next group's first task. When no task is left, say the plan is done instead of handing off.

Done when the touched files, the commit subject and either both next-task commands or the
plan-complete line are printed.

## Boundaries

- Never commit, push, or open a PR.
- The plan file's only changes are those checkboxes; the decisions log is appended to, never
  rewritten.
