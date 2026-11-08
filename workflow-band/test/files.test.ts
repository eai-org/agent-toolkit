import { expect, test } from 'claude-code/testing'
import { rpacFiles, tasksFrom } from '../workflows/rpac/files'

const f = (p: string, m = 1) => ({ path: `/r/.agents/plans/${p}`, mtimeMs: m })
const P = (p: string) => `/r/.agents/plans/${p}`

test('one folder holds one task, files by suffix', () => {
  const names = ['TICKET', 'REQUIREMENTS', 'PLAN', 'DECISIONS', 'MANUAL-TEST', 'SELF-REVIEW', 'SELF-REVIEW-2', 'HANDOVER', 'PR-REVIEW', 'PR-REVIEW.PLAN']
  const tasks = tasksFrom(names.map((n) => f(`123-x/123-x.${n}.md`)))
  expect(tasks.length).toBe(1)
  expect(tasks[0]!.key).toBe('123-x')
  expect(tasks[0]!.title).toBe('123-x')
  expect(rpacFiles(tasks[0]!)).toEqual({
    ticket: P('123-x/123-x.TICKET.md'),
    requirements: P('123-x/123-x.REQUIREMENTS.md'),
    plan: P('123-x/123-x.PLAN.md'),
    decisions: P('123-x/123-x.DECISIONS.md'),
    manualTest: P('123-x/123-x.MANUAL-TEST.md'),
    selfReviews: [P('123-x/123-x.SELF-REVIEW.md'), P('123-x/123-x.SELF-REVIEW-2.md')],
    handovers: [P('123-x/123-x.HANDOVER.md')],
    other: [P('123-x/123-x.PR-REVIEW.md'), P('123-x/123-x.PR-REVIEW.PLAN.md')],
  })
})

test('a re-fetch joins its task', () => {
  const tasks = tasksFrom([f('123-x/123-x.REQUIREMENTS.md'), f('123-x-v2/123-x-v2.TICKET.md'), f('123-x/123-x.TICKET.md')])
  expect(tasks.length).toBe(1)
  expect(rpacFiles(tasks[0]!).ticket).toBe(P('123-x-v2/123-x-v2.TICKET.md'))
})

test('a ticket set gives one task per ticket, not the parent', () => {
  const tasks = tasksFrom([f('100-p/100-p.TICKET.md'), f('100-p/101-w.TICKET.md'), f('100-p/101-w.REQUIREMENTS.md'), f('100-p/102-a.TICKET.md')])
  expect(tasks.map((t) => t.key).sort()).toEqual(['101-w', '102-a'])
})

test('an idea refined without a ticket is a task', () => {
  const tasks = tasksFrom([f('idea/idea.REQUIREMENTS.md')])
  expect(tasks.map((t) => t.key)).toEqual(['idea'])
  expect(rpacFiles(tasks[0]!).ticket).toBeUndefined()
})

test('a folder with only other docs is no task', () => {
  expect(tasksFrom([f('wb/wb.DESIGN.md')])).toEqual([])
})

test('tasks are newest first and carry the newest mtime', () => {
  const tasks = tasksFrom([f('a/a.PLAN.md', 1), f('b/b.PLAN.md', 5), f('a/a.DESIGN.md', 3)])
  expect(tasks.map((t) => [t.key, t.mtimeMs])).toEqual([['b', 5], ['a', 3]])
})

test('an attachment beside a lone ticket keeps the task', () => {
  const tasks = tasksFrom([f('123-x/123-x.TICKET.md'), f('123-x/attachment-1.png')])
  expect(tasks.map((t) => t.key)).toEqual(['123-x'])
  expect(tasks[0]!.files.length).toBe(1)
})

test('a re-fetched ticket set keeps its children and drops the parent, in any order', () => {
  const input = [f('100-p/100-p.TICKET.md'), f('100-p-v2/100-p-v2.TICKET.md'), f('100-p-v2/101-w.TICKET.md'), f('100-p/101-w.REQUIREMENTS.md')]
  for (const files of [input, [...input].reverse()]) {
    const tasks = tasksFrom(files)
    expect(tasks.map((t) => t.key)).toEqual(['101-w'])
    expect(tasks[0]!.files.length).toBe(2)
    expect(rpacFiles(tasks[0]!).ticket).toBe(P('100-p-v2/101-w.TICKET.md'))
  }
})

test('a loose doc joins the only task in its folder, not a folder of several', () => {
  const one = tasksFrom([f('snag/snag.PLAN.md'), f('snag/figma-notes.md')])
  expect(rpacFiles(one[0]!).other).toEqual([P('snag/figma-notes.md')])
  const many = tasksFrom([f('100-p/101-w.TICKET.md'), f('100-p/102-a.TICKET.md'), f('100-p/notes.md')])
  expect(many.flatMap((t) => rpacFiles(t).other)).toEqual([])
})
