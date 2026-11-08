import type { FileInfo, Task } from '../../src/workflow'

export type RpacFiles = {
  ticket?: string
  requirements?: string
  plan?: string
  decisions?: string
  manualTest?: string
  selfReviews: string[]
  handovers: string[]
  other: string[]
}

type Parsed = { file: FileInfo; base: string; stem: string; folder: string; suffix: string; version: number }

const parse = (file: FileInfo): Parsed => {
  const parts = file.path.split('/')
  const name = (parts[parts.length - 1] ?? '').replace(/\.md$/, '')
  const folder = parts[parts.length - 2] ?? ''
  const dot = name.indexOf('.')
  const stem = dot < 0 ? name : name.slice(0, dot)
  const suffix = dot < 0 ? '' : name.slice(dot + 1)
  const v = /^(.+)-v(\d+)$/.exec(stem)
  let base = v ? (v[1] ?? '') : stem
  const folderBase = /^(.+)-v\d+$/.exec(folder)
  if (suffix === 'TICKET' && folderBase && stem === folder) base = folderBase[1] ?? ''
  return { file, base, stem, folder, suffix, version: v ? Number(v[2]) : 1 }
}

const parseAll = (files: FileInfo[]) => files.filter((f) => f.path.endsWith('.md')).map(parse)

const SINGLE: Record<string, keyof RpacFiles> = {
  TICKET: 'ticket', REQUIREMENTS: 'requirements', PLAN: 'plan', DECISIONS: 'decisions', 'MANUAL-TEST': 'manualTest',
}

export function tasksFrom(files: FileInfo[]): Task[] {
  const byBase = new Map<string, Parsed[]>()
  const basesIn = new Map<string, Set<string>>()
  for (const p of parseAll(files)) {
    byBase.set(p.base, [...(byBase.get(p.base) ?? []), p])
    basesIn.set(p.folder, (basesIn.get(p.folder) ?? new Set()).add(p.base))
  }
  const tasks: Task[] = []
  for (const [base, ps] of byBase) {
    if (!ps.some((p) => ['TICKET', 'REQUIREMENTS', 'PLAN'].includes(p.suffix))) continue
    const parent = ps.every((p) => p.suffix === 'TICKET' && p.stem === p.folder) && ps.some((p) => (basesIn.get(p.folder)?.size ?? 0) > 1)
    if (parent) continue
    tasks.push({ key: base, title: base, files: ps.map((p) => p.file), mtimeMs: Math.max(...ps.map((p) => p.file.mtimeMs)) })
  }
  return tasks.sort((a, b) => b.mtimeMs - a.mtimeMs)
}

export function rpacFiles(task: Task): RpacFiles {
  const out: RpacFiles = { selfReviews: [], handovers: [], other: [] }
  const best: Record<string, number> = {}
  for (const p of parseAll(task.files)) {
    const slot = SINGLE[p.suffix]
    if (slot === 'ticket' || slot === 'requirements' || slot === 'plan') {
      if (p.version > (best[slot] ?? 0)) { best[slot] = p.version; out[slot] = p.file.path }
    } else if (slot) out[slot as 'decisions' | 'manualTest'] = p.file.path
    else if (/^SELF-REVIEW(-\d+)?$/.test(p.suffix)) out.selfReviews.push(p.file.path)
    else if (/^HANDOVER(-\d+)?$/.test(p.suffix)) out.handovers.push(p.file.path)
    else out.other.push(p.file.path)
  }
  return out
}
