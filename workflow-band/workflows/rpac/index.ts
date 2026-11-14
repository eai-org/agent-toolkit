import { skillName } from '../../src/runs'
import type { Action, CompactItem, Reader, Row, Run, Status, Workflow } from '../../src/workflow'
import { rpacFiles, tasksFrom, type RpacFiles } from './files'
import { parseTasks, type PlanGroup, type PlanTask } from './plan'

type Arg = 'id' | 'ticket' | 'requirements' | 'plan' | 'none'
type Step = {
  key: string
  label: string
  compact?: string
  skill: string
  kind: 'main' | 'extra'
  file?: 'ticket' | 'requirements' | 'plan' | 'manualTest'
  arg: Arg
  perGroup?: 'selfReviews' | 'handovers'
}

const STEPS: Step[] = [
  { key: 'fetch', label: 'Fetch', compact: 'ticket', skill: 'fetch-ticket', kind: 'main', file: 'ticket', arg: 'id' },
  { key: 'refine', label: 'Refine', compact: 'requirements', skill: 'refine-ticket', kind: 'main', file: 'requirements', arg: 'ticket' },
  { key: 'plan', label: 'Plan', compact: 'plan', skill: 'create-implementation-plan', kind: 'main', file: 'plan', arg: 'requirements' },
  { key: 'split', label: 'Split', compact: 'split', skill: 'split-plan-tasks', kind: 'main', arg: 'plan' },
  { key: 'execute', label: 'Execute', compact: 'execute', skill: 'execute-plan-tasks', kind: 'main', arg: 'plan' },
  { key: 'self-review', label: 'Self-review', compact: 'self-review', skill: 'self-review', kind: 'main', arg: 'none', perGroup: 'selfReviews' },
  { key: 'handover', label: 'Handover', compact: 'handover', skill: 'handover', kind: 'main', arg: 'plan', perGroup: 'handovers' },
  { key: 'manual-test', label: 'Manual test', skill: 'create-manual-test-instructions', kind: 'extra', file: 'manualTest', arg: 'requirements' },
]

const SKILLS = ['fetch-ticket', 'refine-ticket', 'create-implementation-plan', 'create-manual-test-instructions', 'split-plan-tasks', 'execute-plan-tasks', 'self-review', 'handover']
const TICKET_ID = /^([A-Z][A-Z0-9]*-\d+|\d+)(?=-|$)/

const PER_GROUP = STEPS.filter((s) => s.perGroup)

const step = (key: string) => STEPS.find((s) => s.key === key)
const act = (skill: string, args: string): Action => ({ skill, args, label: `▶ ${skill}` })
const tokens = (args: string) => args.split(/\s+/).filter(Boolean)
const matches = (path: string, token: string) => path === token || path.endsWith(`/${token}`)
const allTicked = (g: PlanGroup) => g.tasks.every((t) => t.done)
const groupsOf = async (plan: string | undefined, io: Reader) => (plan ? io.read(plan).then(parseTasks, () => undefined) : undefined)
const latest = (runs: Run[]) => runs.reduce<Run | undefined>((a, r) => (!a || r.at >= a.at ? r : a), undefined)
const isTask = (r: Row) => r.key.startsWith('task-')
const taskId = (r: Row) => r.key.slice('task-'.length)
const isActive = (r: Row) => r.status === 'current' || r.status === 'stopped'
const settled = (r: Row) => r.status === 'done' || r.status === 'unknown'
const item = (r: Row, s: Step, label = s.compact ?? s.label): CompactItem =>
  ({ key: r.key, label, status: r.status, file: r.file, skill: s.skill })

// a parent row's status from its children
function roll(rows: Row[]): Status {
  if (rows.some((r) => r.status === 'stopped')) return 'stopped'
  if (rows.some((r) => r.status === 'current')) return 'current'
  return rows.length && rows.every(settled) ? 'done' : 'todo'
}

function stepStatus(s: Step, f: RpacFiles, split: boolean): Status {
  if (s.file) return f[s.file] ? 'done' : s.key === 'fetch' ? 'skipped' : 'todo'
  return s.key === 'split' && split ? 'done' : 'todo'
}

// the task whose execute run ended while it was still unticked
function stoppedTask(last: Run | undefined, groups: PlanGroup[] | undefined): string | undefined {
  if (last?.endedAt === undefined) return undefined
  const unticked = groups?.some((g) => g.tasks.some((t) => t.id === last.item && !t.done))
  return unticked ? last.item : undefined
}

// A self-review or handover step's status in each group, by group number.
// A file with no remembered run can't be tied to a group, so each spare one covers the earliest finished group left.
function perGroupStatus(groups: PlanGroup[], ran: Run[], files: number): Map<number, Status> {
  let spare = files - ran.length
  const status = new Map<number, Status>()
  for (const g of groups) {
    if (ran.some((r) => r.group === g.n)) status.set(g.n, 'done')
    else if (allTicked(g) && spare > 0) {
      spare--
      status.set(g.n, 'unknown')
    } else status.set(g.n, 'todo')
  }
  return status
}

// an unticked task left behind the furthest done step comes first, else the first open step after it
function nextStep(leaves: Row[]): Row | undefined {
  const far = leaves.map((r) => r.status).lastIndexOf('done')
  const skipped = leaves.slice(0, far).find((r) => isTask(r) && r.status === 'todo')
  return skipped ?? leaves.slice(far + 1).find((r) => r.status === 'todo')
}

// Execute is one band item until the plan is split, then the PR being worked on with its self-review and handover
function executeItems(execute: Row, groupRows: Row[], groups: PlanGroup[] | undefined): CompactItem[] {
  const s = step('execute')!
  if (!groups?.length || execute.status === 'done') return [item(execute, s)]
  let i = groupRows.findIndex(isActive)
  if (i < 0) i = groupRows.findIndex((g) => g.status !== 'done')
  const g = groupRows[i]!
  const n = groups[i]!.n
  const leaf = g.rows!.find(isActive)
  const task = leaf && isTask(leaf) ? ` · task ${taskId(leaf)}` : ''
  return [
    item(g, s, `PR ${n}/${groups.length}${task}`),
    ...PER_GROUP.map((p) => item(g.rows!.find((r) => r.key === `${p.key}-${n}`)!, p)),
  ]
}

export const rpac: Workflow = {
  id: 'rpac',
  name: 'RPAC',
  roots: ['.agents/plans'],
  skills: SKILLS,
  tasks: async (files) => tasksFrom(files),

  taskOf(skill, args, tasks) {
    if (!SKILLS.includes(skillName(skill))) return undefined
    const ts = tokens(args)
    return (
      tasks.find((t) => t.files.some((f) => ts.some((tok) => matches(f.path, tok)))) ??
      tasks.find((t) => t.key === ts[0]) ??
      tasks.find((t) => ts.includes(TICKET_ID.exec(t.key)?.[1] ?? ''))
    )?.key
  },

  async annotate(run, task, io) {
    const s = skillName(run.skill)
    if (s !== 'execute-plan-tasks' && s !== 'self-review' && s !== 'handover') return run
    const groups = (await groupsOf(rpacFiles(task).plan, io)) ?? []
    if (s === 'execute-plan-tasks') {
      const item = tokens(run.args)[1] ?? groups.flatMap((g) => g.tasks).find((t) => !t.done)?.id
      return item ? { ...run, item } : run
    }
    const done = groups.filter(allTicked).map((g) => g.n)
    return done.length ? { ...run, group: Math.max(...done) } : run
  },

  async view(task, all, io) {
    const f: RpacFiles = rpacFiles(task)
    const groups = await groupsOf(f.plan, io)
    const runs = all.filter((r) => r.task === task.key)
    const runsOf = (skill: string) => runs.filter((r) => skillName(r.skill) === skill)
    const id = TICKET_ID.exec(task.key)?.[1]
    const arg: Record<Arg, string> = { id: id ?? '', ticket: f.ticket ?? '', requirements: f.requirements ?? '', plan: f.plan ?? '', none: '' }
    // no action while the file the step reads doesn't exist
    const actions = (s: Step): Action[] => (s.arg !== 'none' && !arg[s.arg] ? [] : [act(s.skill, arg[s.arg])])

    const rows: Row[] = STEPS.filter((s) => !s.perGroup).map((s) => ({
      key: s.key,
      label: s.label,
      status: stepStatus(s, f, groups !== undefined),
      file: s.file && f[s.file],
      actions: (s.key === 'fetch' && !f.ticket) || (s.key === 'execute' && !groups) ? [] : actions(s),
    }))
    const execute = rows.find((r) => r.key === 'execute')!

    const stopped = stoppedTask(latest(runsOf('execute-plan-tasks')), groups)
    const taskRow = (t: PlanTask): Row => {
      const own = act('execute-plan-tasks', `${arg.plan} ${t.id}`)
      const base = { key: `task-${t.id}`, label: `${t.id} ${t.title}` }
      // a stopped task can also go back to planning
      if (t.id === stopped) return { ...base, status: 'stopped', actions: [own, ...actions(step('plan')!)] }
      return { ...base, status: t.done ? 'done' : 'todo', actions: [own] }
    }
    const statusIn = new Map(PER_GROUP.map((s) => [s.key, perGroupStatus(groups ?? [], runsOf(s.skill), f[s.perGroup!].length)]))
    const groupRows: Row[] = (groups ?? []).map((g) => ({
      key: `group-${g.n}`,
      label: `PR ${g.n} ${g.title}`,
      status: 'todo',
      actions: [],
      rows: [
        ...g.tasks.map(taskRow),
        ...PER_GROUP.map((s): Row => ({ key: `${s.key}-${g.n}`, label: s.label, status: statusIn.get(s.key)!.get(g.n)!, actions: actions(s) })),
      ],
    }))
    if (groups) execute.rows = groupRows

    // the steps in the order they run: the main rows, with the groups' rows in place of Execute
    const leaves = [...rows.filter((r) => r !== execute && step(r.key)!.kind !== 'extra'), ...groupRows.flatMap((g) => g.rows!)]
    const next = stopped ? undefined : nextStep(leaves)
    if (next) next.status = 'current'
    for (const g of groupRows) g.status = roll(g.rows!)
    execute.status = groups ? roll(groupRows) : 'todo'

    const compact = [
      ...rows.filter((r) => r !== execute && step(r.key)!.compact && r.status !== 'skipped').map((r) => item(r, step(r.key)!)),
      ...executeItems(execute, groupRows, groups),
    ]

    // the band's run button names the step, the pane's row buttons the skill
    const first = next?.actions[0]
    const run = first && next && { ...first, label: isTask(next) ? `task ${taskId(next)}` : next.label.toLowerCase() }
    return { rows, compact, next: run, stopped, other: [...(f.decisions ? [f.decisions] : []), ...f.other] }
  },
}
