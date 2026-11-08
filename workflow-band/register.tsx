import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'
import { commandName } from './src/actions'
import {
  GREP_DEFS,
  NO_TOKENS,
  addTokens,
  addedLines,
  callsIn,
  defsIn,
  hits,
  inProject,
  isCode,
  isSource,
  isTestCommand,
  parseDefs,
  testCounts,
  type Numbers,
} from './src/metrics'
import { pickTask } from './src/pick'
import { listFiles, reader, repoOf } from './src/repo'
import { runsKey } from './src/runs'
import type { Run } from './src/workflow'
import type { UiState } from './types'
import { drawBand } from './ui/band'
import { WORKFLOWS } from './workflows'

// what /clear starts over
const TASK = { spent: 0, turns: 0, turnCosts: [], tokens: NO_TOKENS, busyMs: 0, reused: [], created: [], removed: [], openCallers: [], tests: { state: 'none' as const } }
const EMPTY: Numbers = { ...TASK, cost: 0, project: '', session: '' }
const UI: UiState = { paneOpen: false, picking: false }

const numbers = atom({ plugin: 'agent-toolkit', key: 'numbers' } as const, EMPTY, { shape: 'numbers-1' })
const shown = atom({ plugin: 'agent-toolkit', key: 'shown' } as const, null, { shape: 'shown-1' })
const ui = atom({ plugin: 'agent-toolkit', key: 'ui' } as const, UI, { shape: 'ui-1' })

const union = (a: string[], b: string[]) => [...new Set([...a, ...b])]
const base = (path: string) => path.replace(/\/+$/, '').split('/').pop() ?? path

// returns the definitions that exist now: what new code can reuse
// a resumed conversation brings its turns along, a cleared one counts from 0 (its turns() reads 1)
async function start($: EngineInterface, resumed: boolean): Promise<Map<string, string>> {
  const grep = await $.process.run(['git', 'grep', '--untracked', '-nE', GREP_DEFS]).catch(() => undefined)
  const repo = await $.session.repo().catch(() => null)
  const project = base(repo?.root ?? (await $.session.cwd()))
  const session = await $.session.id()
  // the cost so far is the baseline for the next turn's own cost
  const usage = await $.session.usage().catch(() => undefined)
  const turns = resumed ? await $.session.turns().catch(() => undefined) : undefined
  await update($, numbers, (n) => ({ ...n, project, session, cost: usage?.cost?.usd ?? n.cost, turns: turns ?? n.turns }))
  return grep?.exitCode === 0 ? parseDefs(grep.stdout) : new Map()
}

async function refresh($: EngineInterface): Promise<void> {
  try {
    const repo = await repoOf($)
    const stored = await $.store.get(runsKey(repo.root))
    const runs = Array.isArray(stored) ? (stored as Run[]) : []
    const where = { session: await $.session.id(), checkout: repo.checkout, pinned: (await read($, ui)).pinned }
    const io = reader($)
    for (const wf of WORKFLOWS) {
      const tasks = await wf.tasks(await listFiles($, repo, wf.roots), io)
      const task = pickTask(tasks, runs, where)
      if (!task) continue
      const view = await wf.view(task, runs, io)
      const names = await Promise.all(wf.skills.map((skill) => commandName($, skill)))
      const installed = wf.skills.filter((_, i) => names[i] !== undefined)
      await update($, shown, () => ({ workflow: wf.id, name: wf.name, repo, task, tasks: tasks.map(({ key, title }) => ({ key, title })), view, installed }))
      return
    }
    await update($, shown, () => null)
  } catch (err) {
    $.ui.log(`workflow-band: refresh failed: ${err instanceof Error ? err.message : String(err)}`, { to: 'debug' })
    await update($, shown, () => null).catch(() => undefined)
  }
}

export const register: Register = (on) => {
  let known = new Map<string, string>()

  on('session.start', async ($, e, next) => {
    known = await start($, true)
    await refresh($)
    return next(e)
  }).catch(($, e, next) => next(e))

  // /clear, /resume and /branch go on under another session id with an empty band and no session.start.
  // Only these commands: a hook on every command labels other plugins' command output with this plugin.
  on('command.run', { command: ['clear', 'resume', 'branch'] }, async ($, e, next) => {
    const session = await $.session.id()
    const result = await next(e)
    if ((await $.session.id()) !== session) {
      known = await start($, e.command !== 'clear').catch(() => known)
      await refresh($)
    }
    return result
  }).catch(($, e, next) => next(e))

  // the cost baseline stays
  on('session.end', async ($, e, next) => {
    if (e.reason === 'clear') await update($, numbers, (n) => ({ ...n, ...TASK }))
    return next(e)
  }).catch(($, e, next) => next(e))

  on('tool.call', async ($, e, next) => {
    if (e.tool === 'Bash') {
      const ran = await next(e)
      if (ran.deny === undefined && isTestCommand(e.command)) {
        const tests = { state: ran.isError ? ('fail' as const) : ('pass' as const), ...testCounts(ran.text ?? '') }
        await update($, numbers, (n) => ({ ...n, tests }))
      }
      return ran
    }

    if (e.tool !== 'Edit' && e.tool !== 'Write') return next(e)

    const file = e.file_path
    // a scratch script outside the project is never reused or called by it
    const repo = await $.session.repo().catch(() => null)
    if (!inProject(file, repo?.root ?? (await $.session.cwd()))) return next(e)
    const before = e.tool === 'Write' ? await $.fs.read(file).catch(() => '') : e.old_string
    const after = e.tool === 'Write' ? e.content : e.new_string
    const ran = await next(e)
    if (ran.deny !== undefined || ran.isError) return ran

    const oldDefs = defsIn(file, before)
    const newDefs = defsIn(file, after)
    const created = isSource(file) ? newDefs.filter((d) => !oldDefs.includes(d)) : []
    const removed = oldDefs.filter((d) => !newDefs.includes(d))
    const reused = isSource(file) ? callsIn(addedLines(before, after), known, newDefs) : []

    await update($, numbers, (n) => ({
      ...n,
      reused: union(n.reused, reused),
      created: union(n.created, created),
      removed: union(n.removed, removed),
      tests: isCode(file) && n.tests.state !== 'none' ? { ...n.tests, state: 'stale' as const } : n.tests,
    }))

    return ran
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const used = e.usage
    if (e.agentId !== undefined) {
      // a subagent's cost is already in the session cost the main turn reads, its tokens aren't
      if (used) await update($, numbers, (n) => ({ ...n, tokens: addTokens(n.tokens, used) }))
      return next(e)
    }

    const usage = await $.session.usage()
    const { removed } = await read($, numbers)

    // a removed or renamed definition that isn't defined again but still called somewhere
    // shortcut: name match with git grep, so a same-named call in another module counts too
    const stillRemoved: string[] = []
    const open: string[] = []
    for (const name of removed) {
      const grep = await $.process.run(['git', 'grep', '--untracked', '-nw', '-e', name]).catch(() => undefined)
      const rows = hits(grep?.stdout ?? '')
      if (rows.some((r) => defsIn(r.file, r.text.trimStart()).includes(name))) continue
      const call = new RegExp(`(?<![\\w$])${name.replace(/\$/g, '\\$')}\\s*\\(`)
      const refs = rows.filter((r) => call.test(r.text)).map((r) => `${r.file}:${r.line}`)
      if (refs.length > 0) {
        stillRemoved.push(name)
        open.push(...refs)
      }
    }

    await update($, numbers, (n) => {
      const cost = usage.cost?.usd ?? n.cost
      // a cost below the baseline means the engine started its ledger over
      const turn = cost >= n.cost ? cost - n.cost : cost
      return {
        ...n,
        cost,
        spent: usage.cost?.usd ?? n.spent + turn,
        turns: n.turns + 1,
        turnCosts: [...n.turnCosts, turn].slice(-20),
        tokens: used ? addTokens(n.tokens, used) : n.tokens,
        busyMs: n.busyMs + e.durationMs,
        removed: stillRemoved,
        openCallers: open,
      }
    })
    await refresh($)
    return next(e)
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    // other mods share this slot and theirs goes below ours. next(e) rejects only when nothing answers beneath
    const below = await next(e).catch(() => undefined)
    return drawBand($, e, below, { numbers: await read($, numbers), shown: await read($, shown), ui: await read($, ui) })
  }).catch(($, e, next) => next(e))
}
