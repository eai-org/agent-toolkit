---
name: execute-plan-tasks
description: Execute one task of a plan's task breakdown, then stop for review.
disable-model-invocation: true
type: flow
license: MIT
metadata:
  version: "0.7"
---

# Execute plan tasks

One task per run — implement it, verify it, tick it, stop. The review between tasks is the point;
never carry on into the next.

Invocation: `/execute-plan-tasks <plan-path> [task-id]`

## Pick the task

Read the plan whole — summary, conventions and overrides, the steps the task cites, acceptance
criteria — then its `## Tasks` section, and the decisions log beside it when it exists
(`<id>-<slug>.DECISIONS.md`, `<id>-<slug>` being the plan filename without `.PLAN.md`): a logged
deviation outranks the plan text it deviates from. Ambiguous or missing plan path → ask. Several
task sections → ask which one this run works from. No task section → stop and point at
`/split-plan-tasks`.

`task-id` given → that task; none → the first unticked one in order. A range or a whole group → run
its first task only, saying the rest need their own runs; a task already ticked → say so and ask
whether to redo it. Its dependencies — earlier tasks in its group, plus every task in each group its
*Depends on* line names — must be ticked; name any unticked dependency and ask before proceeding.

Done when the chosen task, its steps, its acceptance criteria, its dependency state and any logged
deviation that touches it are stated.

## Execute

- **Scope is the task's steps, nothing else**: no work belonging to a later task, no drive-by
  refactors. Work the plan calls for that no task covers → report it, don't absorb it.
- The plan's conventions and overrides bind every task, this one included.
- **Never guess.** What the code settles, settle by reading it; what it doesn't goes to the user as
  one question carrying your recommendation, worded via `explain-in-simple-language` when
  available. Append each settled deviation from the plan, and its why, as one line to the
  decisions log beside the plan (`<id>-<slug>.DECISIONS.md`), creating it if absent. Only a
  deviation confined to the task's own steps and result (an equivalent call, a local adjustment, a
  corrected attempt departing from the plan text) takes this path; a shape-changing one goes to
  Stop to re-plan. Correcting your own implementation needs no question.
- **A copy is not exempt.** A file the plan says to copy or mirror was written for its own
  runtime and tooling: check each setting fits this task's target before copying. A misfit is a
  deviation — settle and log it as above.
- Blocked outright — a step the codebase contradicts, an unmet prerequisite — → stop, leave the
  task unticked, report what blocks it; leave the edits made so far in place and list them with
  the blocker, never revert on your own.
- **Stop to re-plan** (section below) at the task's second failed attempt, or before applying a
  workaround that would change its shape:
  - A failed attempt is the approach the task's steps prescribe, or a corrected version of it,
    falling short of the step's result, the task's *Done when* check or the project's validation
    for a reason rooted in the approach. The first never stops the run: make one corrected
    attempt. Not counted: a slip fixed in passing (typo, missing import, lint or format nit, wrong
    path corrected on sight), or a failure Verify reports as predating the task or outside its
    scope. One count for the whole task, Execute and Verify alike, within this run only — a later
    run starts from zero.
  - A workaround changes the task's shape when it would deliver other than its steps describe,
    add files, areas or behaviour they don't name, change an interface or behaviour later tasks or
    the plan's acceptance criteria rely on, or abandon the approach the plan prescribes for the
    task. Stop as soon as one proves needed, whatever the count.
  - A step the codebase contradicts or an unmet prerequisite stays blocked outright, even when a
    shape-changing workaround could get round it.

Done when every step of the task is implemented, its blocker reported, or the run stopped to
re-plan.

## Verify

Run the task's *Done when* check, then the validation the project's governing docs name — failing
that, its toolchain's lint, tests and build; nothing runnable → say so rather than invent a
command. Fix what this task broke: a failed fix is a failed attempt, and a fix that would change
the task's shape stops the run before it is applied (Stop to re-plan). A failure that predates
the task or lands outside its scope is reported, never fixed silently, and never counted. A *Done
when* or AC only a human can check is handed to the user as the exact steps to perform, never run
by proxy or claimed.

Done when both pass or are handed to the user, every remaining failure is reported with why it
stands, or the run stopped to re-plan.

## Close

Tick the task `- [ ]` → `- [x]`, plus each acceptance criterion it *Satisfies* whose every
satisfying task is now ticked — the plan's only edits, made once verification passed or every
remaining failure is reported as predating the task or outside its scope, never the task's own
*Done when* or AC checks: those pass or are handed to the user. Name the ACs still partly open. A
check handed to the user never holds the task's tick back, while a manual-only AC
stays unticked even when its tasks are ticked; both are listed as pending the user's check. Then
print the files touched, any deviation logged, and the task's *Commit* subject (absent → propose
one in the repo's style) to commit once the change is reviewed. Finally hand off the next unticked
task as its own fenced block under the label "Next task:", holding a single copy-pasteable launch
command — session name and prompt combined, in the launch syntax of the agent tool in use
(vendor-agnostic — `claude` below is only the example; `<slug>` is the plan filename without id
prefix or extension):

```
claude --name execute-tasks-<slug> "/execute-plan-tasks <plan-path> <next-task-id>"
```

Then offer the alternative: one line offering to clear the current session (vendor-agnostic —
`/clear` is only the example) and run the next phase here, then the same labelled block(s) with the
bare prompt, `/execute-plan-tasks <plan-path> <next-task-id>`.

When the finished task completes its group, say so first: the group is one PR, so its tasks get
committed and reviewed before the next group starts. With `/self-review` available, add in both
forms, ahead of the next-task block, a block labelled "Review the group first:" (same `<slug>`),
also when the no-task-left line replaces the next-task block:

```
claude --name self-review-<slug> "/self-review"
```

When no task is left, say in place of the next-task blocks that the plan is done, or, while an
AC is pending the user's check, that its tasks are done and acceptance is pending.

Done when the touched files, the commit subject, the checks pending the user, both `/self-review`
forms when a group completed and it is available, and either both next-task forms or the
no-task-left line are printed.

## Stop to re-plan

Reached only from the stop in Execute or Verify, in place of Close: no checkbox changes — a redone
task stays ticked — and no *Commit* subject, "Next task:" or "Review the group first:" block is
printed. Write no file — the report lives in the session output only, with no plan edit and no
decisions-log line; lines logged earlier in the run stay as they are.

Report, in order:

1. What happened — each approach tried and how it failed, or the workaround needed and why it
   changes the task's shape.
2. Every edit made so far, the decisions-log lines this run appended included — file and change,
   each with whether it is worth keeping and a one-line why; one recording an approach that then
   failed is not, since a later run reads it as outranking the plan. Leave them all in place,
   never revert on your own.
3. A recommendation to revisit the plan, as next-phase hand-off blocks — the agent tool's launch
   syntax, `claude` below only the example, `<slug>` as in Close — each printed only when its
   skill is available:
   - "Re-plan from the requirements, when the task's approach has to change:", on the plan's
     upstream (`<upstream-path>`): its name with `.PLAN` replaced by `.REQUIREMENTS` when that
     exists, else with `.PLAN` removed when that exists. Printed → warn ahead of the blocks that
     re-planning overwrites this plan file, `## Tasks` and ticks included, while its decisions log
     keeps this plan's entries, which a later run would read as outranking the new plan — move
     both aside first. No upstream found → no block; with the skill available, say instead to
     re-plan with `create-implementation-plan` from the requirements document this plan was
     written from.

     ```
     claude --name create-plan-<slug> "/create-implementation-plan <upstream-path>"
     ```

   - "or harden the plan, so a fresh reviewer checks it against its ticket and the code:" —
     starting "or" only after the re-plan block:

     ```
     claude --name harden-plan-<slug> "/harden-artifact <plan-path>"
     ```

   With a block printed, add Close's clear-session alternative: the same labelled blocks with the
   bare prompts, `/create-implementation-plan <upstream-path>` and `/harden-artifact <plan-path>`,
   same order. No block and no in-words re-plan line → recommend revisiting the plan in words.
4. Last, tell the user to pass what happened on to the session they start, and to discard the
   edits not worth keeping before starting it; a redone task → also that it stays ticked, so later
   runs take it as done until they untick it.

Done when what happened, every edit with its keep verdict, the recommendation — both forms of
each printed block, the re-plan one warned, and each in-words line its case calls for — and the
closing advice are printed.

## Boundaries

- Never commit, push, or open a PR.
- The plan file's only changes are those checkboxes; the decisions log is appended to, never
  rewritten.
