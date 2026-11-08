import type { EngineInterface } from 'claude-code'
import { expect, test } from 'claude-code/testing'
import { CANCEL, CLEAR_FIRST, openFile, RUN_HERE, runStep, vscodeLink } from '../src/actions'
import { listFiles, repoOf } from '../src/repo'

// The test kit's `$` only raises events, so the helpers get a hand-made engine.
type Fake = { names?: string[]; answer?: string | Error; os?: string; term?: string; uname?: string; git?: { exitCode: number; stdout: string }; repo?: string | null; tree?: Record<string, { name: string; kind: string }[]> }

function fake(f: Fake = {}) {
  const runs: { command: string; args?: string }[] = []
  const toasts: string[] = []
  const argv: string[][] = []
  const asked: string[] = []
  const $ = {
    command: {
      list: async () => (f.names ?? []).map((name) => ({ name })),
      run: async (r: { command: string; args?: string }) => void runs.push(r),
    },
    ui: {
      ask: async (q: string) => {
        asked.push(q)
        if (f.answer instanceof Error) throw f.answer
        return f.answer ?? CANCEL
      },
      toast: (t: string) => void toasts.push(t),
    },
    env: { get: async (k: string) => (k === 'OS' ? f.os : k === 'TERM_PROGRAM' ? f.term : undefined) },
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
  return { $, runs, toasts, argv, asked }
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

test('a step without args asks without a stray space', async () => {
  const t = fake({ names: ['self-review'], answer: CANCEL })
  await runStep(t.$, { skill: 'self-review', args: '', label: '' }, true)
  expect(t.asked).toEqual(['Run /self-review: clear this session first, or run it here?'])
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

function opener(f: Fake & { linkFails?: boolean; openerFails?: boolean }) {
  const t = fake(f)
  ;(t.$.process as any).run = async (a: string[]) => {
    if (a[0] === 'uname') return { exitCode: 0, stdout: `${f.uname ?? 'Linux'}\n`, stderr: '' }
    t.argv.push(a)
    const fails = f.openerFails || (f.linkFails && a.at(-1)!.startsWith('vscode://'))
    return { exitCode: fails ? 1 : 0, stdout: '', stderr: '' }
  }
  return t
}

test('vscodeLink encodes POSIX and Windows paths, keeping the drive colon', () => {
  expect(vscodeLink('/r/a b.md')).toBe('vscode://file/r/a%20b.md')
  expect(vscodeLink('C:\\Users\\you\\a b.md')).toBe('vscode://file/C:/Users/you/a%20b.md')
})

test('inside VS Code a file opens through a vscode:// link', async () => {
  const t = opener({ uname: 'Darwin', term: 'vscode' })
  await openFile(t.$, '/r/a b.md')
  expect(t.argv).toEqual([['open', 'vscode://file/r/a%20b.md']])
  expect(t.toasts).toEqual([])
})

test('outside VS Code, or when the link fails, the OS opener gets the path', async () => {
  const plain = opener({ uname: 'Darwin' })
  await openFile(plain.$, '/r/a b.md')
  expect(plain.argv).toEqual([['open', '/r/a b.md']])
  const failed = opener({ uname: 'Darwin', term: 'vscode', linkFails: true })
  await openFile(failed.$, '/r/a b.md')
  expect(failed.argv).toEqual([['open', 'vscode://file/r/a%20b.md'], ['open', '/r/a b.md']])
})

test('openFile picks the OS opener per platform', async () => {
  const linux = opener({})
  await openFile(linux.$, '/r/a.md')
  expect(linux.argv).toEqual([['xdg-open', '/r/a.md']])
  const win = opener({ os: 'Windows_NT' })
  await openFile(win.$, 'C:\\a.md')
  expect(win.argv).toEqual([['cmd', '/c', 'start', '', 'C:\\a.md']])
  const winCode = opener({ os: 'Windows_NT', term: 'vscode' })
  await openFile(winCode.$, 'C:\\r\\a.md')
  expect(winCode.argv).toEqual([['cmd', '/c', 'start', '', 'vscode://file/C:/r/a.md']])
})

test('openFile toasts when the link and the OS opener both fail', async () => {
  const bad = opener({ uname: 'Darwin', term: 'vscode', openerFails: true })
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

test('repoOf falls back to the cwd outside a repo', async () => {
  expect(await repoOf(fake().$)).toEqual({ root: '/c', checkout: '/c' })
})

test('repoOf takes the parent of the git common dir', async () => {
  expect(await repoOf(fake({ repo: '/w', git: { exitCode: 0, stdout: '/r/.git\n' } }).$)).toEqual({ root: '/r', checkout: '/w' })
})
