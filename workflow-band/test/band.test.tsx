import type { On } from 'claude-code'
import { expect, mock, test, type Engine } from 'claude-code/testing'
import type { Run } from '../src/workflow'

const PLAN = [
  '# Plan', '## Acceptance criteria', '- [ ] AC-1 a', '- [x] AC-2 b', '## Tasks',
  '### Group 1 — Approval API', '- *Depends on* nothing', '- [x] **1.1 Add endpoint** — steps 1–2', '  - *Done when* x',
  '- [X] **1.2 Add tests** — step 3', '### Group 2 - Approval screen', '- [x] **2.1 Add approve button** — step 4',
  '- [ ] **2.2 Add reject dialog** — step 5', '- [ ] **2.3 Show status badge** — step 6', '## Notes', '- [ ] not a task',
].join('\n')

const ROOT = '/r/.agents/plans'
const DIR = `${ROOT}/123-x`
const REQ = `${DIR}/123-x.REQUIREMENTS.md`
const PLN = `${DIR}/123-x.PLAN.md`
const SKILLS = ['fetch-ticket', 'refine-ticket', 'harden-artifact', 'create-implementation-plan', 'create-manual-test-instructions', 'split-plan-tasks', 'execute-plan-tasks', 'self-review', 'handover']
const EXECUTING: Partial<Run>[] = [
  { skill: 'harden-artifact', file: REQ },
  { skill: 'harden-artifact', file: PLN },
  { skill: 'self-review', group: 1 },
  { skill: 'handover', group: 1 },
]
const STOPPED: Partial<Run>[] = [{ skill: 'execute-plan-tasks', item: '2.2', endedAt: 5 }]
const TREE: Record<string, { name: string; kind: 'file' | 'dir' }[]> = {
  [ROOT]: [{ name: '123-x', kind: 'dir' }],
  [DIR]: ['TICKET', 'REQUIREMENTS', 'PLAN'].map((s) => ({ name: `123-x.${s}.md`, kind: 'file' as const })),
}

const BAND = {
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 12, bodyColumns: 160, scroll: { offset: 0, bodyRows: 12 }, view: {} },
} as const

type World = { runs?: Partial<Run>[]; skills?: string[]; noFolder?: boolean; columns?: number }

async function band($: Engine, on: On, w: World = {}) {
  mock.clock(on)
  mock.env(on, {})
  const runs = (w.runs ?? EXECUTING).map((r) => ({ skill: 's', args: '', task: '123-x', at: 1, session: 's1', checkout: '/r', ...r }))
  mock.store(on, { 'runs:/r': runs })
  const argv: string[][] = []
  const commands: { command: string; args?: string }[] = []
  const copied: string[] = []
  on('session.id', () => ({ value: 's1' }))
  on('session.cwd', () => ({ value: '/r' }))
  on('session.repo', () => ({ value: { root: '/r' } }) as never)
  on('session.usage', () => ({ value: { startedAt: 0, cost: { usd: 0 } } }) as never)
  on('process.run', ($, e) => {
    argv.push([...e.argv])
    const stdout = e.argv[1] === 'rev-parse' ? '/r/.git\n' : e.argv[0] === 'uname' ? 'Darwin\n' : ''
    return { value: { exitCode: e.argv[1] === 'grep' ? 1 : 0, stdout, stderr: '' } } as never
  })
  on('fs.list', ($, e) => {
    const entries = w.noFolder ? undefined : TREE[e.path]
    return (entries ? { value: entries.map((x) => ({ ...x, size: 1, mtimeMs: x.kind === 'file' ? 1 : 0 })) } : { deny: 'missing' }) as never
  })
  on('fs.read', ($, e) => (e.path === PLN ? { value: PLAN } : { deny: 'missing' }) as never)
  on('command.list', () => ({ value: (w.skills ?? SKILLS).map((name) => ({ name, description: '', source: 'userSettings' })) }) as never)
  on('command.run', ($, e) => {
    commands.push({ command: e.command, args: e.args })
    return { text: '' }
  })
  on('ui.copy', ($, e) => {
    copied.push(e.text)
    return { value: { isCopied: true as const } }
  })
  on('ui.toast', () => ({ value: undefined }))
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('turn.complete', () => ({ text: '' }))
  on('session.end', () => ({ sessionId: 's1' }))
  await $.session.start({ cwd: '/r', surface: null } as never)
  const ui = await $.ui.mount({ plugin: 'agent-toolkit', surface: 'terminal', ...BAND, props: { ...BAND.props, bodyColumns: w.columns ?? 160 } })
  return { ui, argv, commands, copied }
}

test('the steps row shows the shown task and the run button', async ($, on) => {
  const { ui, commands } = await band($, on)
  expect(await ui.find({ type: 'Text', text: 'ticket' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'PR 2/2 · task 2.2' })).toBeDefined()
  expect((await ui.find({ key: 'run' }))?.text).toContain('▶ Run')
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

test('copy hands the numbers over as Markdown', async ($, on) => {
  const { ui, copied } = await band($, on)
  await ui.press({ key: 'copy' })
  expect(copied.length).toBe(1)
  expect(copied[0]).toContain('| Cost |')
  expect(copied[0]).toContain('## 123-x')
  await ui.unmount()
})
