import type { EngineInterface } from 'claude-code'
import type { Repo } from '../types'
import type { Workflow } from './workflow'

const FILE = '.agents/workflow-band.json'
const unsafe = (p: string) => /^([/\\]|[A-Za-z]:[/\\])/.test(p) || p.split(/[/\\]/).includes('..')
let warned: string | undefined

export function parseConfig(text: string): Record<string, string> | undefined {
  try {
    const folders = (JSON.parse(text) as { folders?: unknown } | null)?.folders
    if (folders === undefined) return {}
    if (typeof folders !== 'object' || folders === null || Array.isArray(folders)) return undefined
    const map = folders as Record<string, unknown>
    return Object.values(map).every((v) => typeof v === 'string' && v !== '') ? (map as Record<string, string>) : undefined
  } catch {
    return undefined
  }
}

export function rootsFor(wf: Workflow, folders: Record<string, string>): readonly string[] {
  const dir = Object.hasOwn(folders, wf.id) ? folders[wf.id] : undefined
  return dir && !unsafe(dir) ? [dir] : wf.roots
}

export async function readFolders($: EngineInterface, repo: Repo): Promise<Record<string, string>> {
  for (const base of new Set([repo.checkout, repo.root])) {
    const text = await $.fs.read(`${base}/${FILE}`).then(String, () => undefined)
    if (text === undefined) continue
    const folders = parseConfig(text)
    if (folders) return folders
    const session = await $.session.id()
    if (warned !== session) {
      warned = session
      $.ui.toast(`workflow-band: ${FILE} is invalid, using the default folders`)
    }
    return {}
  }
  return {}
}
