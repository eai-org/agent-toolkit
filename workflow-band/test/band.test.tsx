import { expect, test } from 'claude-code/testing'
import { SKILLS, PLN, STOPPED, band } from './world'

test('the steps row shows the shown task and the run button', async ($, on) => {
  const { ui, commands } = await band($, on)
  expect(await ui.find({ type: 'Text', text: 'ticket' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'PR 2/2 · task 2.2' })).toBeDefined()
  expect((await ui.find({ key: 'run' }))?.text).toBe('▶ Run task 2.2')
  await ui.press({ key: 'run' })
  expect(commands).toEqual([{ command: 'execute-plan-tasks', args: `${PLN} 2.2` }])
  await ui.unmount()
})

test('a done step opens its file', async ($, on) => {
  const { ui, argv } = await band($, on)
  await ui.press({ key: 'item-plan' })
  expect(argv).toContainEqual(['open', PLN])
  await ui.unmount()
})

test('no planning folder: numbers only', async ($, on) => {
  const { ui } = await band($, on, { noFolder: true })
  expect(await ui.find({ key: 'run' })).toBeUndefined()
  expect(await ui.find({ key: 'steps' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /\$0\.00/ })).toBeDefined()
  await ui.unmount()
})

test('a narrow terminal still fits', async ($, on) => {
  const { ui } = await band($, on, { columns: 60 })
  const steps = await ui.find({ key: 'steps' })
  expect(steps?.text.length).toBeLessThanOrEqual(60)
  for (const t of await ui.findAll({ type: 'Text' })) expect(t.text.length).toBeLessThanOrEqual(60)
  expect(await ui.find({ text: /requirements/ })).toBeUndefined()
  expect(await ui.find({ key: 'run' })).toBeDefined()
  await ui.unmount()
})

test('a missing skill has no run button', async ($, on) => {
  const { ui } = await band($, on, { skills: SKILLS.filter((s) => s !== 'execute-plan-tasks') })
  expect(await ui.find({ key: 'steps' })).toBeDefined()
  expect(await ui.find({ key: 'run' })).toBeUndefined()
  await ui.unmount()
})

test('a stopped task warns instead of offering a run', async ($, on) => {
  const { ui } = await band($, on, { runs: STOPPED })
  expect(await ui.find({ type: 'Text', text: /⚠ task 2\.2 stopped/ })).toBeDefined()
  expect(await ui.find({ key: 'run' })).toBeUndefined()
  await ui.unmount()
})

test('a main turn counts and /clear starts the count over', async ($, on) => {
  const { ui } = await band($, on)
  expect(await ui.find({ type: 'Text', text: '0 turns' })).toBeDefined()
  await $.turn.complete({ answer: '', durationMs: 1000, agentId: 'a1' } as never)
  await $.turn.complete({ answer: '', durationMs: 1000 } as never)
  expect(await ui.find({ type: 'Text', text: '1 turn' })).toBeDefined()
  await $.session.end({ reason: 'clear', sessionId: 's1' } as never)
  expect(await ui.find({ type: 'Text', text: '0 turns' })).toBeDefined()
  await ui.unmount()
})

test('a resumed conversation asks before it runs, and /clear counts from 0', async ($, on) => {
  const { ui, asked, commands } = await band($, on, { turns: 5 })
  expect(await ui.find({ type: 'Text', text: '5 turns' })).toBeDefined()
  await ui.press({ key: 'run' })
  expect(asked.length).toBe(1)
  expect(commands).toEqual([{ command: 'execute-plan-tasks', args: `${PLN} 2.2` }])
  await $.session.end({ reason: 'clear', sessionId: 's1' } as never)
  await $.command.run({ command: 'clear', args: '' } as never)
  expect(await ui.find({ type: 'Text', text: '0 turns' })).toBeDefined()
  await $.command.run({ command: 'resume', args: '' } as never)
  expect(await ui.find({ type: 'Text', text: '5 turns' })).toBeDefined()
  await ui.unmount()
})

test('copy hands the numbers over as Markdown', async ($, on) => {
  const { ui, copied } = await band($, on)
  await ui.press({ key: 'copy' })
  expect(copied.length).toBe(1)
  expect(copied[0]).toContain('| Cost |')
  expect(copied[0]).toContain('## 123-x')
  await ui.unmount()
})

test('a prompt before the first turn finishes asks before it runs', async ($, on) => {
  const { ui, asked } = await band($, on)
  await $.prompt.submit({ text: 'hi' } as never)
  await ui.press({ key: 'run' })
  expect(asked.length).toBe(1)
  await $.session.end({ reason: 'clear', sessionId: 's1' } as never)
  await ui.press({ key: 'run' })
  expect(asked.length).toBe(1)
  await ui.unmount()
})

test('no run button while a turn is running', async ($, on) => {
  const { ui } = await band($, on, { working: true })
  expect(await ui.find({ key: 'steps' })).toBeDefined()
  expect(await ui.find({ key: 'run' })).toBeUndefined()
  await ui.unmount()
})

test('a refresh lists the commands once', async ($, on) => {
  const { ui, listed } = await band($, on)
  const before = listed.length
  await $.turn.complete({ answer: '', durationMs: 1 } as never)
  expect(listed.length - before).toBe(1)
  await ui.unmount()
})
