import type { Run, Task } from './workflow'

export type Where = { session: string; checkout: string; pinned?: string }

// Highest `at`; a tie goes to the later run in the array.
const byRecency = (runs: Run[]): Run[] =>
  runs.map((r, i) => ({ r, i })).sort((a, b) => b.r.at - a.r.at || b.i - a.i).map((x) => x.r)

export const newest = (tasks: Task[]): Task | undefined =>
  tasks.reduce<Task | undefined>((best, t) => (!best || t.mtimeMs > best.mtimeMs ? t : best), undefined)

export const pickTask = (tasks: Task[], runs: Run[], where: Where): Task | undefined => {
  const find = (key: string) => tasks.find((t) => t.key === key)
  const pinned = where.pinned === undefined ? undefined : find(where.pinned)
  if (pinned) return pinned
  const levels = [(r: Run) => r.session === where.session, (r: Run) => r.checkout === where.checkout, () => true]
  for (const level of levels)
    for (const r of byRecency(runs.filter(level))) {
      const t = find(r.task)
      if (t) return t
    }
  return newest(tasks)
}
