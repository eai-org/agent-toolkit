import type { Run } from './workflow'

export const RUNS_CAP = 200

export const skillName = (name: string): string => name.slice(name.indexOf(':') + 1)

export const argsOf = (text: string): string => {
  const i = text.lastIndexOf('\nARGUMENTS: ')
  if (i >= 0) return text.slice(i + 12).trim()
  return text.startsWith('ARGUMENTS: ') ? text.slice(11).trim() : ''
}

export const addRun = (runs: Run[], run: Run): Run[] => [...runs, run].slice(-RUNS_CAP)

export const endRuns = (runs: Run[], session: string, at: number): Run[] =>
  runs.map((r) => (r.session === session && r.endedAt === undefined ? { ...r, endedAt: at } : r))

export const runsKey = (repo: string): string => `runs:${repo}`
