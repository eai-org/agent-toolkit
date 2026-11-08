import { atom, read, update } from 'claude-code'
import type { EngineInterface } from 'claude-code'
import { nameIn } from './actions'
import { NO_TOKENS, type Numbers } from './metrics'
import { newest, pickTask } from './pick'
import { listFiles, reader, repoOf } from './repo'
import { runsKey } from './runs'
import type { Run } from './workflow'
import type { Shown, UiState } from '../types'
import { WORKFLOWS } from '../workflows'

export const PANE = 'workflow'

// what /clear starts over
export const TASK = { spent: 0, turns: 0, talking: false, turnCosts: [], tokens: NO_TOKENS, busyMs: 0, reused: [], created: [], removed: [], openCallers: [], tests: { state: 'none' as const } }
const EMPTY: Numbers = { ...TASK, cost: 0, project: '', session: '' }
const UI: UiState = { paneOpen: false, picking: false, hidden: false }

export const numbers = atom({ plugin: 'agent-toolkit', key: 'numbers' } as const, EMPTY, { shape: 'numbers-2' })
export const shown = atom({ plugin: 'agent-toolkit', key: 'shown' } as const, null, { shape: 'shown-1' })
export const ui = atom({ plugin: 'agent-toolkit', key: 'ui' } as const, UI, { shape: 'ui-2' })

export async function refresh($: EngineInterface): Promise<void> {
  try {
    const repo = await repoOf($)
    const stored = await $.store.get(runsKey(repo.root))
    const runs = Array.isArray(stored) ? (stored as Run[]) : []
    const where = { session: await $.session.id(), checkout: repo.checkout, pinned: (await read($, ui)).pinned }
    const io = reader($)
    for (const wf of WORKFLOWS) {
      const tasks = await wf.tasks(await listFiles($, repo, wf.roots), io)
      const resolved = runs.map((r) =>
        r.task || !wf.skills.includes(r.skill) ? r : { ...r, task: wf.taskOf(r.skill, r.args, tasks) ?? newest(tasks.filter((t) => t.mtimeMs >= r.at))?.key ?? '' },
      )
      const task = pickTask(tasks, resolved, where)
      if (!task) continue
      const view = await wf.view(task, resolved, io)
      const names = (await $.command.list()).map((c) => c.name)
      const installed = wf.skills.filter((skill) => nameIn(names, skill) !== undefined)
      await update($, shown, () => ({ workflow: wf.id, name: wf.name, repo, task, tasks: tasks.map(({ key, title }) => ({ key, title })), view, installed }))
      return
    }
    await update($, shown, () => null)
  } catch (err) {
    $.ui.log(`workflow-band: refresh failed: ${err instanceof Error ? err.message : String(err)}`, { to: 'debug' })
    await update($, shown, () => null).catch(() => undefined)
  }
}

export function setNumbers($: EngineInterface, fn: (n: Numbers) => Numbers) {
  return update($, numbers, fn)
}

export function setUi($: EngineInterface, fn: (u: UiState) => UiState) {
  return update($, ui, fn)
}

export function readNumbers($: EngineInterface): Promise<Numbers> {
  return read($, numbers)
}
export function readShown($: EngineInterface): Promise<Shown | null> {
  return read($, shown)
}
export function readUi($: EngineInterface): Promise<UiState> {
  return read($, ui)
}

// the pane flag outlives a reload or /clear, the pane itself may not
export async function syncPane($: EngineInterface): Promise<void> {
  const open = await $.ui.panes().then((panes) => panes.some((p) => p.id === PANE && p.isShown), () => false)
  await update($, ui, (u) => ({ ...u, paneOpen: open }))
}
