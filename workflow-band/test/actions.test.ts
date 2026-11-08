import type { EngineInterface } from 'claude-code'
import { expect, test } from 'claude-code/testing'
import { CANCEL, CLEAR_FIRST, openFile, RUN_HERE, runStep } from '../src/actions'
import { listFiles, repoOf, shown } from '../src/repo'

// The test kit's `$` only raises events, so the helpers get a hand-made engine.
type Fake = { names?: string[]; answer?: string | Error; os?: string; uname?: string; git?: { exitCode: number; stdout: string }; repo?: string | null; tree?: Record<string, { name: string; kind: string }[]> }

function fake(f: Fake = {}) {
  const runs: { command: string; args?: string }[] = []
  const toasts: string[] = []
  const argv: string[][] = []
  const $ = {
    command: {
      list: async () => (f.names ?? []).map((name) => ({ name })),
      run: async (r: { command: string; args?: string }) => void runs.push(r),
    },
    ui: {
      ask: async () => {
        if (f.answer instanceof Error) throw f.answer
        return f.answer ?? CANCEL
      },
      toast: (t: string) => void toasts.push(t),
    },
    env: { get: async () => f.os },
    process: {
      run: async (a: string[]) => {
        argv.push(a)
        if (a[0] === 'uname') return { exitCode: 0, stdout: `${f.uname ?? 'Linux'}\n`, stderr: '' }
        if (a[0] === 'git') return { exitCode: f.git?.exitCode ?? 128, stdout: f.git?.stdout ?? '', stderr: '' }
        return { exitCode: 0, stdout: '', stderr: '' }
      },
    },
    session: { cwd: async () => '/c', repo: async () => (f.repo ? { root: f.repo } : null) },
    fs: {
      list: async (p: string) => {
        const t = f.tree?.[p]
        if (!t) throw new Error('missing')
        return t.map((e) => ({ ...e, size: 1, mtimeMs: e.kind === 'file' ? 7 : 0 }))
      },
    },
  } as unknown as EngineInterface
  return { $, runs, toasts, argv }
}

const action = { skill: 'split-plan-tasks', args: 'p.md', label: '' }

test('a fresh session runs the namespaced skill directly', async () => {
  const t = fake({ names: ['agent-toolkit:split-plan-tasks'] })
  await runStep(t.$, action, false)
  expect(t.runs).toEqual([{ command: 'agent-toolkit:split-plan-tasks', args: 'p.md' }])
})

test('a bare name wins over a namespaced one', async () => {
  const t = fake({ names: ['x:split-plan-tasks', 'split-plan-tasks'] })
  await runStep(t.$, action, false)
  expect(t.runs[0]!.command).toBe('split-plan-tasks')
})

test('clear first clears, then runs', async () => {
  const t = fake({ names: ['split-plan-tasks'], answer: CLEAR_FIRST })
  await runStep(t.$, action, true)
  expect(t.runs.map((r) => r.command)).toEqual(['clear', 'split-plan-tasks'])
})

test('run here runs only the skill', async () => {
  const t = fake({ names: ['split-plan-tasks'], answer: RUN_HERE })
  await runStep(t.$, action, true)
  expect(t.runs.map((r) => r.command)).toEqual(['split-plan-tasks'])
})

test('cancel, free text and a dismissed dialog run nothing', async () => {
  for (const answer of [CANCEL, 'whatever', new Error('dismissed')]) {
    const t = fake({ names: ['split-plan-tasks'], answer })
    await runStep(t.$, action, true)
    expect(t.runs).toEqual([])
  }
})

test('an unlisted skill toasts', async () => {
  const t = fake({ names: ['other'] })
  await runStep(t.$, action, false)
  expect(t.runs).toEqual([])
  expect(t.toasts).toEqual(["split-plan-tasks isn't installed"])
})

test('openFile picks the opener per platform and toasts on failure', async () => {
  const mac = fake({ uname: 'Darwin' })
  await openFile(mac.$, '/r/a.md')
  expect(mac.argv.pop()).toEqual(['open', '/r/a.md'])
  const linux = fake()
  await openFile(linux.$, '/r/a.md')
  expect(linux.argv.pop()).toEqual(['xdg-open', '/r/a.md'])
  const win = fake({ os: 'Windows_NT' })
  await openFile(win.$, 'C:\\a.md')
  expect(win.argv.pop()).toEqual(['cmd', '/c', 'start', '', 'C:\\a.md'])
  const bad = fake()
  ;(bad.$.process as any).run = async () => ({ exitCode: 1, stdout: '', stderr: 'no' })
  await openFile(bad.$, '/r/a.md')
  expect(bad.toasts).toEqual(['Could not open /r/a.md'])
})

test('listFiles reads the main checkout when the worktree has no folder', async () => {
  const t = fake({
    tree: {
      '/r/.agents/plans': [{ name: 't', kind: 'dir' }, { name: 'x.txt', kind: 'file' }, { name: 'bad', kind: 'dir' }, { name: 'top.md', kind: 'file' }],
      '/r/.agents/plans/t': [{ name: 'a.md', kind: 'file' }, { name: 'b.png', kind: 'file' }],
    },
  })
  expect(await listFiles(t.$, { root: '/r', checkout: '/w' }, ['.agents/plans', 'gone'])).toEqual([
    { path: '/r/.agents/plans/top.md', mtimeMs: 7 },
    { path: '/r/.agents/plans/t/a.md', mtimeMs: 7 },
  ])
})

test('listFiles prefers the checkout when it has the folder', async () => {
  const t = fake({ tree: { '/w/p': [{ name: 'a.md', kind: 'file' }], '/r/p': [{ name: 'b.md', kind: 'file' }] } })
  expect(await listFiles(t.$, { root: '/r', checkout: '/w' }, ['p'])).toEqual([{ path: '/w/p/a.md', mtimeMs: 7 }])
})

test('shown cuts the checkout prefix only', () => {
  expect(shown('/w/x/a.md', '/w')).toBe('x/a.md')
  expect(shown('/wx/a.md', '/w')).toBe('/wx/a.md')
})

test('repoOf falls back to the cwd outside a repo', async () => {
  expect(await repoOf(fake().$)).toEqual({ root: '/c', checkout: '/c' })
})

test('repoOf takes the parent of the git common dir', async () => {
  expect(await repoOf(fake({ repo: '/w', git: { exitCode: 0, stdout: '/r/.git\n' } }).$)).toEqual({ root: '/r', checkout: '/w' })
})
