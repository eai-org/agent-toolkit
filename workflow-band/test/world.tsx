import type { On } from 'claude-code'
import { mock, type Engine } from 'claude-code/testing'
import { RUN_HERE } from '../src/actions'
import type { Run } from '../src/workflow'

const PLAN = [
  '# Plan', '## Acceptance criteria', '- [ ] AC-1 a', '- [x] AC-2 b', '## Tasks',
  '### Group 1 — Approval API', '- *Depends on* nothing', '- [x] **1.1 Add endpoint** — steps 1–2', '  - *Done when* x',
  '- [X] **1.2 Add tests** — step 3', '### Group 2 - Approval screen', '- [x] **2.1 Add approve button** — step 4',
  '- [ ] **2.2 Add reject dialog** — step 5', '- [ ] **2.3 Show status badge** — step 6', '## Notes', '- [ ] not a task',
].join('\n')

export const ROOT = '/r/.agents/plans'
const DIR = `${ROOT}/123-x`
const REQ = `${DIR}/123-x.REQUIREMENTS.md`
export const PLN = `${DIR}/123-x.PLAN.md`
export const SKILLS = ['fetch-ticket', 'refine-ticket', 'harden-artifact', 'create-implementation-plan', 'create-manual-test-instructions', 'split-plan-tasks', 'execute-plan-tasks', 'self-review', 'handover']
const EXECUTING: Partial<Run>[] = [
  { skill: 'harden-artifact', file: REQ },
  { skill: 'harden-artifact', file: PLN },
  { skill: 'self-review', group: 1 },
  { skill: 'handover', group: 1 },
]
export const STOPPED: Partial<Run>[] = [{ skill: 'execute-plan-tasks', item: '2.2', endedAt: 5 }]
const TREE: Record<string, { name: string; kind: 'file' | 'dir' }[]> = {
  [ROOT]: [{ name: '123-x', kind: 'dir' }, { name: '99-old', kind: 'dir' }],
  [`${ROOT}/99-old`]: [{ name: '99-old.TICKET.md', kind: 'file' as const }],
  [DIR]: ['TICKET', 'REQUIREMENTS', 'PLAN'].map((s) => ({ name: `123-x.${s}.md`, kind: 'file' as const })),
}

const BAND = {
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 12, bodyColumns: 160, scroll: { offset: 0, bodyRows: 12 }, view: {} },
} as const

export type World = { runs?: Partial<Run>[]; skills?: string[]; noFolder?: boolean; columns?: number; turns?: number }

export async function band($: Engine, on: On, w: World = {}) {
  mock.clock(on)
  mock.env(on, {})
  const runs = (w.runs ?? EXECUTING).map((r) => ({ skill: 's', args: '', task: '123-x', at: 1, session: 's1', checkout: '/r', ...r }))
  mock.store(on, { 'runs:/r': runs })
  const argv: string[][] = []
  const commands: { command: string; args?: string }[] = []
  const copied: string[] = []
  const asked: string[] = []
  const toasts: string[] = []
  let session = 's1'
  on('session.id', () => ({ value: session }))
  on('session.turns', () => ({ value: w.turns ?? 0 }))
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
    if (['clear', 'resume', 'branch'].includes(e.command)) session = `${session}+${e.command}`
    commands.push({ command: e.command, args: e.args })
    return { text: '' }
  })
  on('ui.copy', ($, e) => {
    copied.push(e.text)
    return { value: { isCopied: true as const } }
  })
  on('ui.toast', ($, e) => {
    toasts.push(e.text)
    return { value: undefined }
  })
  on('tool.call', { tool: 'AskUserQuestion' }, ($, e) => {
    const question = e.questions[0]?.question ?? ''
    asked.push(question)
    return { result: { questions: e.questions, answers: { [question]: RUN_HERE } }, text: '' } as never
  })
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('turn.complete', () => ({ text: '' }))
  on('session.end', () => ({ sessionId: 's1' }))
  await $.session.start({ cwd: '/r', surface: null } as never)
  const ui = await $.ui.mount({ plugin: 'agent-toolkit', surface: 'terminal', ...BAND, props: { ...BAND.props, bodyColumns: w.columns ?? 160 } })
  return { ui, argv, commands, copied, asked, toasts }
}

