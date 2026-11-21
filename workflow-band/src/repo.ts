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

type Entries = Awaited<ReturnType<EngineInterface['fs']['list']>>

const mdFiles = (dir: string, entries: Entries): FileInfo[] =>
  entries.filter((e) => e.kind === 'file' && e.name.endsWith('.md')).map((e) => ({ path: `${dir}/${e.name}`, mtimeMs: e.mtimeMs }))

// the folder and one level of subfolders
async function mdIn($: EngineInterface, dir: string): Promise<FileInfo[]> {
  const entries = await $.fs.list(dir).catch(() => undefined)
  if (!entries) return []
  const subdirs = entries.filter((e) => e.kind === 'dir').map((e) => `${dir}/${e.name}`)
  const nested = await Promise.all(subdirs.map((sub) => $.fs.list(sub).then((inside) => mdFiles(sub, inside), () => [])))
  return [...mdFiles(dir, entries), ...nested.flat()]
}

export async function listFiles($: EngineInterface, repo: Repo, roots: readonly string[]): Promise<FileInfo[]> {
  const out = await Promise.all(roots.map(async (r) => {
    const here = await mdIn($, `${repo.checkout}/${r}`)
    // A gitignored planning folder only exists in the main checkout.
    return here.length || repo.root === repo.checkout ? here : mdIn($, `${repo.root}/${r}`)
  }))
  return out.flat()
}

export function reader($: EngineInterface): Reader {
  return { read: async (path) => String(await $.fs.read(path)) }
}
