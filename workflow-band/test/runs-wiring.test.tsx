import { expect, test } from 'claude-code/testing'
import type { Run } from '../src/workflow'
import { ROOT, band } from './world'

const OTHER = '/r/.agents/plans/99-old/99-old.TICKET.md'
const stored = (saved: Record<string, unknown>) => (saved['runs:/r'] ?? []) as Run[]

test('a typed run is remembered and moves the band', async ($, on) => {
  const { ui, saved } = await band($, on, { runs: [] })
  await $.skill.prompt({ skill: 'agent-toolkit:refine-ticket', text: `x\n\nARGUMENTS: ${OTHER}` } as never)
  const runs = stored(saved)
  expect(runs).toHaveLength(1)
  expect(runs[0]).toMatchObject({ skill: 'refine-ticket', task: '99-old', session: 's1', checkout: '/r' })
  expect(await ui.find({ type: 'Text', text: '◉ requirements' })).toBeDefined()
  await ui.unmount()
})

test('a run without a path goes to the shown task', async ($, on) => {
  const { ui, saved } = await band($, on)
  await $.skill.prompt({ skill: 'self-review', text: 'x' } as never)
  const last = (stored(saved)).at(-1)
  expect(last).toMatchObject({ skill: 'self-review', task: '123-x', group: 1 })
  await ui.unmount()
})

test('other skills are ignored and a path matching no task stays off the shown task', async ($, on) => {
  const { ui, saved } = await band($, on, { runs: [] })
  expect((await ui.find({ key: 'run' }))?.text).toBe('▶ Run task 2.2')
  const a = await $.skill.prompt({ skill: 'grill-me', text: 'x' } as never)
  const b = await $.skill.prompt({ skill: 'refine-ticket', text: 'x\n\nARGUMENTS: /elsewhere/x.md' } as never)
  expect(a.text).toBe('x')
  expect(b.text).toBe('x\n\nARGUMENTS: /elsewhere/x.md')
  expect(stored(saved).map((r) => [r.skill, r.task])).toEqual([['refine-ticket', '']])
  expect((await ui.find({ key: 'run' }))?.text).toBe('▶ Run task 2.2')
  await ui.unmount()
})

test('a ticket fetched before its folder exists shows once the folder appears', async ($, on) => {
  const { ui, saved, tree } = await band($, on)
  await $.skill.prompt({ skill: 'fetch-ticket', text: 'x\n\nARGUMENTS: 555' } as never)
  expect(stored(saved).at(-1)).toMatchObject({ skill: 'fetch-ticket', task: '', session: 's1', checkout: '/r' })
  expect(await ui.find({ type: 'Text', text: '◉ requirements' })).toBeUndefined()
  tree[ROOT] = [...tree[ROOT]!, { name: '555-y', kind: 'dir' }]
  tree[`${ROOT}/555-y`] = [{ name: '555-y.TICKET.md', kind: 'file', mtimeMs: 20 }]
  await $.turn.complete({ answer: '', durationMs: 1 } as never)
  expect(await ui.find({ type: 'Text', text: '◉ requirements' })).toBeDefined()
  await ui.unmount()
})

test('a refined idea shows the task created after it', async ($, on) => {
  const { ui, saved, tree } = await band($, on)
  await $.skill.prompt({ skill: 'refine-ticket', text: 'x\n\nARGUMENTS: add dark mode' } as never)
  expect(stored(saved).at(-1)).toMatchObject({ skill: 'refine-ticket', task: '' })
  tree[ROOT] = [...tree[ROOT]!, { name: 'dark-mode', kind: 'dir' }]
  tree[`${ROOT}/dark-mode`] = [{ name: 'dark-mode.REQUIREMENTS.md', kind: 'file', mtimeMs: 20 }]
  await $.turn.complete({ answer: '', durationMs: 1 } as never)
  expect((await ui.find({ key: 'run' }))?.text).toBe('▶ Run harden requirements')
  await ui.unmount()
})

test('the end of a session marks its runs ended', async ($, on) => {
  const { ui, saved } = await band($, on, { runs: [] })
  await $.skill.prompt({ skill: 'refine-ticket', text: `x\n\nARGUMENTS: ${OTHER}` } as never)
  await $.session.end({ reason: 'other', sessionId: 's1' } as never)
  expect((stored(saved))[0]?.endedAt).toBeDefined()
  await ui.unmount()
})

test('off hides the band, on brings it back', async ($, on) => {
  const { ui, saved } = await band($, on)
  expect((await $.command.run({ command: 'workflow-band', args: 'off' } as never)).text).toBe('Workflow band hidden. /workflow-band on brings it back.')
  expect(await ui.find({ key: 'run' })).toBeUndefined()
  expect((await $.command.run({ command: 'workflow-band', args: 'on' } as never)).text).toBe('Workflow band shown.')
  expect(await ui.find({ key: 'run' })).toBeDefined()
  expect((await $.command.run({ command: 'workflow-band', args: 'x' } as never)).text).toBe('Usage: /workflow-band off|on')
  await ui.unmount()
})
