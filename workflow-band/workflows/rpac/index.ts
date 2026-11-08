import { skillName } from '../../src/runs'
import type { Action, CompactItem, Reader, Row, Run, Status, Workflow } from '../../src/workflow'
import { rpacFiles, tasksFrom, type RpacFiles } from './files'
import { parseTasks, type PlanGroup } from './plan'

type Arg = 'id' | 'ticket' | 'requirements' | 'plan' | 'none'
type Step = {
  key: string
  label: string
  compact?: string
  skill: string
  kind: 'main' | 'optional' | 'extra'
  file?: 'ticket' | 'requirements' | 'plan' | 'manualTest'
  arg: Arg
  perGroup?: 'selfReviews' | 'handovers'
}

const STEPS: Step[] = [
  { key: 'fetch', label: 'Fetch', compact: 'ticket', skill: 'fetch-ticket', kind: 'main', file: 'ticket', arg: 'id' },
  { key: 'refine', label: 'Refine', compact: 'requirements', skill: 'refine-ticket', kind: 'main', file: 'requirements', arg: 'ticket' },
  { key: 'harden-requirements', label: 'Harden requirements', skill: 'harden-artifact', kind: 'optional', arg: 'requirements' },
  { key: 'plan', label: 'Plan', compact: 'plan', skill: 'create-implementation-plan', kind: 'main', file: 'plan', arg: 'requirements' },
  { key: 'harden-plan', label: 'Harden plan', skill: 'harden-artifact', kind: 'optional', arg: 'plan' },
  { key: 'split', label: 'Split', compact: 'split', skill: 'split-plan-tasks', kind: 'main', arg: 'plan' },
  { key: 'execute', label: 'Execute', compact: 'execute', skill: 'execute-plan-tasks', kind: 'main', arg: 'plan' },
  { key: 'self-review', label: 'Self-review', compact: 'self-review', skill: 'self-review', kind: 'main', arg: 'none', perGroup: 'selfReviews' },
  { key: 'handover', label: 'Handover', compact: 'handover', skill: 'handover', kind: 'main', arg: 'plan', perGroup: 'handovers' },
  { key: 'manual-test', label: 'Manual test', skill: 'create-manual-test-instructions', kind: 'extra', file: 'manualTest', arg: 'requirements' },
]

const SKILLS = ['fetch-ticket', 'refine-ticket', 'harden-artifact', 'create-implementation-plan', 'create-manual-test-instructions', 'split-plan-tasks', 'execute-plan-tasks', 'self-review', 'handover']
const TICKET_ID = /^([A-Z][A-Z0-9]*-\d+|\d+)(?=-|$)/

const step = (key: string) => STEPS.find((s) => s.key === key)
const act = (skill: string, args: string): Action => ({ skill, args, label: `▶ ${skill}` })
const tokens = (args: string) => args.split(/\s+/).filter(Boolean)
const matches = (path: string, token: string) => path === token || path.endsWith(`/${token}`)
const allTicked = (g: PlanGroup) => g.tasks.every((t) => t.done)
const groupsOf = async (plan: string | undefined, io: Reader) => (plan ? io.read(plan).then(parseTasks, () => undefined) : undefined)
const latest = (runs: Run[]) => runs.reduce<Run | undefined>((a, r) => (!a || r.at >= a.at ? r : a), undefined)
const settled = (r: Row) => r.status === 'done' || r.status === 'unknown'
const roll = (rows: Row[]): Status =>
  rows.some((r) => r.status === 'stopped') ? 'stopped' : rows.some((r) => r.status === 'current') ? 'current' : rows.length && rows.every(settled) ? 'done' : 'todo'
const item = (r: Row, s: Step, label = s.compact ?? s.label): CompactItem =>
  ({ key: r.key, label, status: r.status, file: r.file, skill: s.skill, hardened: r.hardened })

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
    const [first, second] = tokens(run.args)
    if (s === 'harden-artifact') {
      const file = first === undefined ? undefined : task.files.find((f) => matches(f.path, first))?.path
      return file ? { ...run, file } : run
    }
    if (s !== 'execute-plan-tasks' && s !== 'self-review' && s !== 'handover') return run
    const groups = (await groupsOf(rpacFiles(task).plan, io)) ?? []
    if (s === 'execute-plan-tasks') {
      const item = second ?? groups.flatMap((g) => g.tasks).find((t) => !t.done)?.id
      return item ? { ...run, item } : run
    }
    const done = groups.filter(allTicked).map((g) => g.n)
    return done.length ? { ...run, group: Math.max(...done) } : run
  },

  async view(task, all, io) {
    const f: RpacFiles = rpacFiles(task)
    const groups = await groupsOf(f.plan, io)
    const runs = all.filter((r) => r.task === task.key)
    const of = (skill: string) => runs.filter((r) => skillName(r.skill) === skill)
    const id = TICKET_ID.exec(task.key)?.[1]
    const arg: Record<Arg, string> = { id: id ?? '', ticket: f.ticket ?? '', requirements: f.requirements ?? '', plan: f.plan ?? '', none: '' }
    const hardened = new Set(of('harden-artifact').map((r) => r.file))
    const actions = (s: Step): Action[] => (s.arg !== 'none' && !arg[s.arg] ? [] : [act(s.skill, arg[s.arg])])

    const status = (s: Step): Status => {
      if (s.file) return f[s.file] ? 'done' : s.key === 'fetch' ? 'skipped' : 'todo'
      if (s.skill === 'harden-artifact') return hardened.has(arg[s.arg]) ? 'done' : 'todo'
      return s.key === 'split' && groups ? 'done' : 'todo'
    }
    const rows: Row[] = STEPS.filter((s) => !s.perGroup).map((s) => {
      const file = s.file && f[s.file]
      const hardenable = STEPS.some((h) => h.skill === 'harden-artifact' && h.arg === s.file)
      return {
        key: s.key,
        label: s.label,
        status: status(s),
        file,
        hardened: file && hardenable && hardened.has(file) ? true : undefined,
        actions: (s.key === 'fetch' && !f.ticket) || (s.key === 'execute' && !groups) ? [] : actions(s),
      }
    })

    const last = latest(of('execute-plan-tasks'))
    const stopped = last?.endedAt !== undefined && groups?.some((g) => g.tasks.some((t) => t.id === last.item && !t.done)) ? last.item : undefined
    const perGroup = STEPS.filter((s) => s.perGroup)
    // a file with no remembered run can't be tied to a group, so each spare one covers the earliest finished group left
    const groupStatus = new Map<string, Status>()
    for (const s of perGroup) {
      const done = of(s.skill)
      let spare = f[s.perGroup!].length - done.length
      for (const g of groups ?? []) {
        const ran = done.some((r) => r.group === g.n)
        const unknown = !ran && allTicked(g) && spare > 0
        if (unknown) spare--
        groupStatus.set(`${s.key}-${g.n}`, ran ? 'done' : unknown ? 'unknown' : 'todo')
      }
    }
    const groupRows: Row[] = (groups ?? []).map((g) => ({
      key: `group-${g.n}`,
      label: `PR ${g.n} ${g.title}`,
      status: 'todo',
      actions: [],
      rows: [
        ...g.tasks.map((t): Row => {
          const own = act('execute-plan-tasks', `${arg.plan} ${t.id}`)
          return t.id === stopped
            ? { key: `task-${t.id}`, label: `${t.id} ${t.title}`, status: 'stopped', actions: [own, ...actions(step('harden-plan')!), ...actions(step('plan')!)] }
            : { key: `task-${t.id}`, label: `${t.id} ${t.title}`, status: t.done ? 'done' : 'todo', actions: [own] }
        }),
        ...perGroup.map((s): Row => ({ key: `${s.key}-${g.n}`, label: s.label, status: groupStatus.get(`${s.key}-${g.n}`)!, actions: actions(s) })),
      ],
    }))

    const execute = rows.find((r) => r.key === 'execute')!
    if (groups) execute.rows = groupRows
    const leaves = [...rows.filter((r) => r !== execute && step(r.key)!.kind !== 'extra'), ...groupRows.flatMap((g) => g.rows!)]
    const far = leaves.map((r) => r.status).lastIndexOf('done')
    leaves.forEach((r, i) => {
      if (i < far && r.status !== 'done' && step(r.key)?.kind === 'optional') r.status = 'skipped'
    })
    const open = leaves.slice(0, far).find((r) => r.key.startsWith('task-') && r.status === 'todo')
    const next = stopped ? undefined : open ?? leaves.slice(far + 1).find((r) => r.status === 'todo')
    if (next) next.status = 'current'
    for (const g of groupRows) g.status = roll(g.rows!)
    execute.status = groups ? roll(groupRows) : 'todo'

    const compact = rows.filter((r) => r !== execute && step(r.key)!.compact && r.status !== 'skipped').map((r) => item(r, step(r.key)!))
    if (!groups?.length || execute.status === 'done') compact.push(item(execute, step('execute')!))
    else {
      let i = groupRows.findIndex((g) => g.status === 'current' || g.status === 'stopped')
      if (i < 0) i = groupRows.findIndex((g) => g.status !== 'done')
      const g = groupRows[i]!
      const n = groups[i]!.n
      const leaf = g.rows!.find((r) => r.status === 'current' || r.status === 'stopped')
      const task = leaf?.key.startsWith('task-') ? ` · task ${leaf.key.slice(5)}` : ''
      compact.push(
        item(g, step('execute')!, `PR ${n}/${groups.length}${task}`),
        ...perGroup.map((s) => item(g.rows!.find((r) => r.key === `${s.key}-${n}`)!, s)),
      )
    }

    // the band's run button names the step, the pane's row buttons the skill
    const first = next?.actions[0]
    const run = first && next && { ...first, label: next.key.startsWith('task-') ? `task ${next.key.slice(5)}` : next.label.toLowerCase() }
    return { rows, compact, next: run, stopped, other: [...(f.decisions ? [f.decisions] : []), ...f.other] }
  },
}
