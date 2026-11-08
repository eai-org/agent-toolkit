import { expect, test } from 'claude-code/testing'
import { rpac } from '../workflows/rpac'
import type { FileInfo, Row, Run } from '../src/workflow'

const PLAN = [
  '# Plan', '## Acceptance criteria', '- [ ] AC-1 a', '- [x] AC-2 b', '## Tasks',
  '### Group 1 — Approval API', '- *Depends on* nothing', '- [x] **1.1 Add endpoint** — steps 1–2', '  - *Done when* x',
  '- [X] **1.2 Add tests** — step 3', '### Group 2 - Approval screen', '- [x] **2.1 Add approve button** — step 4',
  '- [ ] **2.2 Add reject dialog** — step 5', '- [ ] **2.3 Show status badge** — step 6', '## Notes', '- [ ] not a task',
].join('\n')

const P = (p: string) => `/r/.agents/plans/${p}`
const REQ = P('123-x/123-x.REQUIREMENTS.md')
const PLN = P('123-x/123-x.PLAN.md')
const f = (p: string): FileInfo => ({ path: P(p), mtimeMs: 1 })
const run = (o: Partial<Run>): Run => ({ skill: 's', args: '', task: '123-x', at: 1, session: 's1', checkout: '/r', ...o })
const reader = (m: Record<string, string>) => ({
  read: async (p: string) => {
    const v = m[p]
    if (v === undefined) throw new Error(`ENOENT ${p}`)
    return v
  },
})

const view = async (suffixes: string[], plan = PLAN, runs: Partial<Run>[] = []) => {
  const io = reader({ [PLN]: plan })
  const task = (await rpac.tasks(suffixes.map((s) => f(`123-x/123-x.${s}.md`)), io))[0]!
  return rpac.view(task, runs.map(run), io)
}

const find = (rows: Row[], key: string): Row | undefined => {
  for (const r of rows) {
    const hit = r.key === key ? r : r.rows && find(r.rows, key)
    if (hit) return hit
  }
}

const SPLIT = ['TICKET', 'REQUIREMENTS', 'PLAN']
const tick = (...ids: string[]) => ids.reduce((p, id) => p.replace(`[ ] **${id}`, `[x] **${id}`), PLAN)

test('before planning, hardening the requirements is next', async () => {
  const v = await view(['TICKET', 'REQUIREMENTS'])
  expect(find(v.rows, 'fetch')?.status).toBe('done')
  expect(find(v.rows, 'refine')?.status).toBe('done')
  expect(v.next).toMatchObject({ skill: 'harden-artifact', args: REQ, label: 'harden requirements' })
})

test('an optional step passed over is skipped', async () => {
  const v = await view(SPLIT, '# Plan\n- [ ] AC-1 a\n')
  expect(find(v.rows, 'harden-requirements')?.status).toBe('skipped')
  expect(v.next).toMatchObject({ skill: 'harden-artifact', args: PLN })
})

test('executing shows the group and task', async () => {
  const v = await view(SPLIT, PLAN, [
    { skill: 'harden-artifact', file: REQ },
    { skill: 'harden-artifact', file: PLN },
    { skill: 'self-review', group: 1 },
    { skill: 'handover', group: 1 },
  ])
  expect(find(v.rows, 'refine')?.hardened).toBe(true)
  expect(find(v.rows, 'plan')?.hardened).toBe(true)
  expect(v.compact.filter((c) => c.hardened).map((c) => c.label)).toEqual(['requirements', 'plan'])
  expect(v.next).toMatchObject({ skill: 'execute-plan-tasks', args: `${PLN} 2.2`, label: 'task 2.2' })
  expect(find(v.rows, 'task-2.2')?.actions[0]?.label).toBe('▶ execute-plan-tasks')
  expect(v.compact.map((c) => c.label)).toEqual(['ticket', 'requirements', 'plan', 'split', 'PR 2/2 · task 2.2', 'self-review', 'handover'])
  expect(v.compact.map((c) => c.status)).toEqual(['done', 'done', 'done', 'done', 'current', 'todo', 'todo'])
})

test('files with no remembered run are unknown, not guessed', async () => {
  const v = await view([...SPLIT, 'SELF-REVIEW', 'HANDOVER'])
  expect(find(v.rows, 'self-review-1')?.status).toBe('unknown')
  expect(find(v.rows, 'handover-1')?.status).toBe('unknown')
  expect(v.compact.some((c) => c.hardened)).toBe(false)
  expect(find(v.rows, 'refine')?.hardened).toBeUndefined()
  expect(v.next).toMatchObject({ skill: 'execute-plan-tasks', args: `${PLN} 2.2` })
})

test('a finished group without a review file asks for the review', async () => {
  const v = await view(SPLIT, PLAN.replace('[x] **2.1', '[ ] **2.1'))
  expect(v.next).toMatchObject({ skill: 'self-review', args: '', label: 'self-review' })
})

test('a run that ended with its task unticked shows stopped', async () => {
  const v = await view(SPLIT, PLAN, [{ skill: 'execute-plan-tasks', item: '2.2', endedAt: 5 }])
  const row = find(v.rows, 'task-2.2')
  expect(row?.status).toBe('stopped')
  expect(v.stopped).toBe('2.2')
  expect(v.next).toBeUndefined()
  expect(row?.actions.map((a) => [a.skill, a.args])).toEqual([
    ['execute-plan-tasks', `${PLN} 2.2`],
    ['harden-artifact', PLN],
    ['create-implementation-plan', REQ],
  ])
  expect(find(v.rows, 'group-2')?.status).toBe('stopped')
  expect(find(v.rows, 'execute')?.status).toBe('stopped')
  expect(v.compact[4]).toMatchObject({ label: 'PR 2/2 · task 2.2', status: 'stopped' })
})

test('a task left open before ticked ones is next', async () => {
  const v = await view(SPLIT, tick('2.3'), [
    { skill: 'execute-plan-tasks', item: '2.2', endedAt: 5, at: 1 },
    { skill: 'execute-plan-tasks', item: '2.3', endedAt: 9, at: 6 },
  ])
  expect(v.next).toMatchObject({ skill: 'execute-plan-tasks', args: `${PLN} 2.2` })
  expect(v.compact[4]).toMatchObject({ label: 'PR 2/2 · task 2.2', status: 'current' })
})

test('a review file with no remembered run covers only the earliest finished group', async () => {
  const v = await view([...SPLIT, 'SELF-REVIEW', 'HANDOVER'], tick('2.2', '2.3'))
  expect(find(v.rows, 'self-review-1')?.status).toBe('unknown')
  expect(find(v.rows, 'handover-1')?.status).toBe('unknown')
  expect(find(v.rows, 'self-review-2')?.status).toBe('current')
  expect(find(v.rows, 'handover-2')?.status).toBe('todo')
  expect(v.next).toMatchObject({ skill: 'self-review', args: '' })
  expect(find(v.rows, 'execute')?.status).not.toBe('done')
})

test('hardening the ticket marks nothing hardened', async () => {
  const v = await view(SPLIT, PLAN, [{ skill: 'harden-artifact', file: P('123-x/123-x.TICKET.md') }])
  expect(find(v.rows, 'fetch')?.hardened).toBeUndefined()
  expect(v.compact.some((c) => c.hardened)).toBe(false)
})

test('an unsplit plan offers nothing to execute', async () => {
  const v = await view(SPLIT, '# Plan\n- [ ] AC-1 a\n')
  expect(find(v.rows, 'execute')?.actions).toEqual([])
})

test('an empty Tasks section is split but not executed', async () => {
  const v = await view(SPLIT, '# Plan\n## Tasks\n')
  expect(find(v.rows, 'split')?.status).toBe('done')
  expect(find(v.rows, 'execute')?.status).toBe('todo')
  expect(v.compact.at(-1)).toMatchObject({ label: 'execute', status: 'todo' })
})

test('an idea without a ticket skips fetch, and rows missing their input file offer nothing to run', async () => {
  const io = reader({})
  const task = (await rpac.tasks([f('idea/idea.REQUIREMENTS.md')], io))[0]!
  const v = await rpac.view(task, [], io)
  expect(find(v.rows, 'fetch')?.status).toBe('skipped')
  expect(find(v.rows, 'fetch')?.actions).toEqual([])
  expect(v.compact[0]?.label).toBe('requirements')
  expect(find(v.rows, 'split')?.actions).toEqual([])
  expect(find(v.rows, 'execute')?.actions).toEqual([])
  expect(find(v.rows, 'plan')?.actions.map((a) => [a.skill, a.args])).toEqual([['create-implementation-plan', P('idea/idea.REQUIREMENTS.md')]])
})

test('taskOf finds the task by a checkout-relative path, only for RPAC skills', async () => {
  const tasks = await rpac.tasks([f('123-x/123-x.PLAN.md'), f('idea/idea.REQUIREMENTS.md'), f('add-x/add-x.REQUIREMENTS.md')], reader({}))
  expect(rpac.taskOf('agent-toolkit:execute-plan-tasks', '.agents/plans/123-x/123-x.PLAN.md 2.2', tasks)).toBe('123-x')
  expect(rpac.taskOf('refine-ticket', 'idea', tasks)).toBe('idea')
  expect(rpac.taskOf('fetch-ticket', '123', tasks)).toBe('123-x')
  expect(rpac.taskOf('refine-ticket', 'add dark mode', tasks)).toBeUndefined()
  expect(rpac.taskOf('other-skill', '.agents/plans/123-x/123-x.PLAN.md', tasks)).toBeUndefined()
})

test('annotate fills the task item, group and hardened file', async () => {
  const io = reader({ [PLN]: PLAN })
  const task = (await rpac.tasks(SPLIT.map((s) => f(`123-x/123-x.${s}.md`)), io))[0]!
  expect((await rpac.annotate(run({ skill: 'execute-plan-tasks', args: PLN }), task, io)).item).toBe('2.2')
  expect((await rpac.annotate(run({ skill: 'self-review' }), task, io)).group).toBe(1)
  expect((await rpac.annotate(run({ skill: 'harden-artifact', args: '.agents/plans/123-x/123-x.PLAN.md' }), task, io)).file).toBe(PLN)
})
