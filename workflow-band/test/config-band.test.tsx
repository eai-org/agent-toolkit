import { expect, test } from 'claude-code/testing'
import { band } from './world'

const MOVED = { '/r/work/plans': [{ name: '456-y', kind: 'dir' as const }], '/r/work/plans/456-y': [{ name: '456-y.TICKET.md', kind: 'file' as const }], '/r/.agents/plans': [] }
const CONFIG = '/r/.agents/workflow-band.json'

test('a configured folder is where the task is found', async ($, on) => {
  const { ui } = await band($, on, { runs: [], tree: MOVED, files: { [CONFIG]: '{"folders":{"rpac":"work/plans"}}' } })
  expect(await ui.find({ type: 'Text', text: 'ticket' })).toBeDefined()
  await ui.unmount()
})

test('an invalid file means the defaults and one toast', async ($, on) => {
  const { ui, toasts } = await band($, on, { tree: MOVED, files: { [CONFIG]: '{nope' } })
  await $.turn.complete({ answer: '', durationMs: 1 } as never)
  expect(await ui.find({ key: 'steps' })).toBeUndefined()
  expect(toasts).toEqual(['workflow-band: .agents/workflow-band.json is invalid, using the default folders'])
  await ui.unmount()
})
