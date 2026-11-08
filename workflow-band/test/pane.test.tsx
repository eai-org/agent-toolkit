import { expect, test, type Engine } from 'claude-code/testing'
import { PLN, SKILLS, band } from './world'

const PANE = {
  plugin: 'agent-toolkit',
  surface: 'terminal',
  component: 'Pane',
  requestId: 'workflow',
  props: { title: 'x', isFocused: false, bodyColumns: 100, placement: 'dock', scroll: { offset: 0, bodyRows: 30 }, view: {} },
} as const

async function pane($: Engine, on: Parameters<typeof band>[1], w: Parameters<typeof band>[2] = {}) {
  on('ui.open', () => ({ value: { isPlaced: true } }))
  const w0 = await band($, on, w)
  return { ...w0, pane: await $.ui.mount(PANE) }
}

test('expand opens the pane and the band drops its steps', async ($, on) => {
  const opened: unknown[] = []
  on('ui.open', (_, e) => {
    opened.push(e)
    return { value: { isPlaced: true } }
  })
  const { ui } = await band($, on)
  await ui.press({ key: 'expand' })
  expect(opened).toEqual([{ id: 'workflow', title: 'RPAC · 123-x' }])
  expect(await ui.find({ key: 'run' })).toBeUndefined()
  expect(await ui.find({ key: 'compact' })).toBeDefined()
  await ui.unmount()
})

test('the pane lists every step and the current group\'s tasks', async ($, on) => {
  const { pane: p } = await pane($, on)
  expect(await p.find({ type: 'Text', text: /Harden requirements/ })).toBeDefined()
  expect(await p.find({ type: 'Text', text: /2\.2 Add reject dialog/ })).toBeDefined()
  expect(await p.find({ type: 'Text', text: /PR 1 Approval API/ })).toBeDefined()
  expect(await p.find({ type: 'Text', text: /1\.1 Add endpoint/ })).toBeUndefined()
  await p.unmount()
})

test('a row\'s file and skill are one press away', async ($, on) => {
  const { pane: p, argv, commands } = await pane($, on)
  await p.press({ key: 'file-plan' })
  expect(argv).toContainEqual(['open', PLN])
  await p.press({ key: 'act-task-2.2' })
  expect(commands).toEqual([{ command: 'execute-plan-tasks', args: `${PLN} 2.2` }])
  await p.unmount()
})

test('the switcher pins another task', async ($, on) => {
  const { pane: p } = await pane($, on)
  await p.press({ key: 'pick' })
  expect(await p.find({ key: 'task-123-x' })).toBeDefined()
  await p.press({ key: 'task-123-x' })
  expect(await p.find({ type: 'Text', text: 'RPAC · 123-x' })).toBeDefined()
  expect(await p.find({ key: 'task-123-x' })).toBeUndefined()
  await p.unmount()
})

test('compacting closes the pane and brings the steps row back', async ($, on) => {
  on('ui.close', () => ({ value: undefined }))
  const { ui } = await pane($, on)
  await ui.press({ key: 'expand' })
  expect(await ui.find({ key: 'run' })).toBeUndefined()
  await ui.press({ key: 'compact' })
  expect(await ui.find({ key: 'run' })).toBeDefined()
  await ui.unmount()
})

test('a missing skill has no button', async ($, on) => {
  const { pane: p } = await pane($, on, { skills: SKILLS.filter((s) => s !== 'split-plan-tasks') })
  expect(await p.find({ key: 'act-split' })).toBeUndefined()
  expect(await p.find({ key: 'act-plan' })).toBeDefined()
  await p.unmount()
})
