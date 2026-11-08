import type { EngineInterface } from 'claude-code'
import type { Repo } from '../types'
import type { FileInfo, Reader } from './workflow'

export type { Repo } from '../types'

const parent = (p: string) => p.replace(/\/+$/, '').replace(/\/[^/]*$/, '') || '/'

export async function repoOf($: EngineInterface): Promise<Repo> {
  const cwd = await $.session.cwd()
  try {
    const checkout = (await $.session.repo())?.root
    const git = await $.process.run(['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'], { cwd })
    const common = git.stdout.trim()
    if (git.exitCode !== 0 || !common || !checkout) return { root: cwd, checkout: cwd }
    return { root: parent(common), checkout }
  } catch {
    return { root: cwd, checkout: cwd }
  }
}

async function mdIn($: EngineInterface, dir: string): Promise<FileInfo[]> {
  const entries = await $.fs.list(dir).catch(() => undefined)
  if (!entries) return []
  const files = entries.filter((e) => e.kind === 'file' && e.name.endsWith('.md')).map((e) => ({ path: `${dir}/${e.name}`, mtimeMs: e.mtimeMs }))
  const nested = await Promise.all(entries.filter((e) => e.kind === 'dir').map((e) => $.fs.list(`${dir}/${e.name}`).then(
    (sub) => sub.filter((f) => f.kind === 'file' && f.name.endsWith('.md')).map((f) => ({ path: `${dir}/${e.name}/${f.name}`, mtimeMs: f.mtimeMs })),
    () => [],
  )))
  return [...files, ...nested.flat()]
}

export async function listFiles($: EngineInterface, repo: Repo, roots: readonly string[]): Promise<FileInfo[]> {
  const out = await Promise.all(roots.map(async (r) => {
    const here = await mdIn($, `${repo.checkout}/${r}`)
    // A gitignored planning folder only exists in the main checkout.
    return here.length || repo.root === repo.checkout ? here : mdIn($, `${repo.root}/${r}`)
  }))
  return out.flat()
}

export const shown = (path: string, checkout: string) => (path.startsWith(`${checkout}/`) ? path.slice(checkout.length + 1) : path)

export function reader($: EngineInterface): Reader {
  return { read: async (path) => String(await $.fs.read(path)) }
}
