import { expect, test } from 'claude-code/testing'
import type { Run } from '../src/workflow'
import { band } from './world'

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

test('other skills and bad paths are ignored', async ($, on) => {
  const { ui, saved } = await band($, on, { noFolder: true, runs: [] })
  const a = await $.skill.prompt({ skill: 'grill-me', text: 'x' } as never)
  const b = await $.skill.prompt({ skill: 'refine-ticket', text: 'x\n\nARGUMENTS: /elsewhere/x.md' } as never)
  expect(a.text).toBe('x')
  expect(b.text).toBe('x\n\nARGUMENTS: /elsewhere/x.md')
  expect(stored(saved)).toEqual([])
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
