export type PlanTask = { id: string; title: string; done: boolean }
export type PlanGroup = { n: number; title: string; tasks: PlanTask[] }

const GROUP = /^###\s+Group\s+(\d+)\s*[—–-]\s*(.+?)\s*$/
const TASK = /^- \[( |x|X)\]\s+\*\*(\S+)\s+(.+?)\*\*/

export function parseTasks(md: string): PlanGroup[] | undefined {
  const lines = md.split(/\r?\n/)
  const start = lines.findIndex((l) => /^##\s+Tasks\s*$/.test(l))
  if (start < 0) return undefined
  const groups: PlanGroup[] = []
  for (const line of lines.slice(start + 1)) {
    if (/^##\s/.test(line)) break
    const g = GROUP.exec(line)
    if (g) {
      groups.push({ n: Number(g[1]), title: g[2] ?? '', tasks: [] })
      continue
    }
    const t = TASK.exec(line)
    const last = groups[groups.length - 1]
    if (t && last) last.tasks.push({ id: t[2] ?? '', title: t[3] ?? '', done: t[1] !== ' ' })
  }
  return groups
}
