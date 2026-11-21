import type { EngineInterface, Register } from 'claude-code'
import {
  GREP_DEFS,
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
  type Tests,
} from './src/metrics'
import { errorText } from './src/actions'
import { endRuns, addRun, argsOf, readRuns, runsKey, skillName } from './src/runs'
import { readFolders, rootsFor } from './src/config'
import { listFiles, reader, repoOf } from './src/repo'
import type { Run } from './src/workflow'
import { WORKFLOWS } from './workflows'
import { PANE, TASK, readNumbers, readShown, readUi, refresh, setNumbers, setUi, syncPane } from './src/state'
import { drawBand } from './ui/band'
import { drawPane } from './ui/pane'

// name -> "file:line"
type Defs = Map<string, string>

const union = (a: string[], b: string[]) => [...new Set([...a, ...b])]
const base = (path: string) => path.replace(/\/+$/, '').split('/').pop() ?? path
const passOn = <E, R>(_$: unknown, e: E, next: (e: E) => R): R => next(e)

const gitGrep = ($: EngineInterface, ...args: string[]) =>
  $.process.run(['git', 'grep', '--untracked', ...args]).catch(() => undefined)

const projectRoot = async ($: EngineInterface) =>
  (await $.session.repo().catch(() => null))?.root ?? (await $.session.cwd())

const logFailure = ($: EngineInterface, what: string, err: unknown) =>
  $.ui.log(`workflow-band: ${what} failed: ${errorText(err)}`, { to: 'debug' })

const drawState = async ($: EngineInterface) => ({
  numbers: await readNumbers($),
  shown: await readShown($),
  ui: await readUi($),
})

// returns the definitions that exist now: what new code can reuse
// a resumed conversation brings its turns along, a cleared one counts from 0 (its turns() reads 1)
async function start($: EngineInterface, resumed: boolean): Promise<Defs> {
  const grep = await gitGrep($, '-nE', GREP_DEFS)
  const project = base(await projectRoot($))
  const session = await $.session.id()
  // the cost so far is the baseline for the next turn's own cost
  const usage = await $.session.usage().catch(() => undefined)
  const turns = resumed ? await $.session.turns().catch(() => undefined) : undefined
  await setNumbers($, (n) => ({
    ...n,
    project,
    session,
    cost: usage?.cost?.usd ?? n.cost,
    turns: turns ?? n.turns,
    talking: n.talking || (turns ?? 0) > 0,
  }))
  return grep?.exitCode === 0 ? parseDefs(grep.stdout) : new Map()
}

async function recordRun($: EngineInterface, skill: string, args: string): Promise<void> {
  const wf = WORKFLOWS.find((w) => w.skills.includes(skill))
  if (!wf) return
  const repo = await repoOf($)
  const io = reader($)
  const folders = await readFolders($, repo)
  const tasks = await wf.tasks(await listFiles($, repo, rootsFor(wf, folders)), io)

  const shown = await readShown($)
  const onShow = shown?.workflow === wf.id ? shown.task.key : undefined
  // arguments that match no task yet give a run without one: refresh ties it to its task once the files exist
  const key = wf.taskOf(skill, args, tasks) ?? (args ? '' : onShow)
  const task = tasks.find((t) => t.key === key)
  if (!task && key !== '') return

  const plain: Run = { skill, args, task: task?.key ?? '', at: await $.clock.now(), session: await $.session.id(), checkout: repo.checkout }
  const run = task ? await wf.annotate(plain, task, io) : plain
  await $.store.set(runsKey(repo.root), addRun(await readRuns($, repo.root), run))
  await setUi($, (u) => ({ ...u, pinned: undefined }))
  await refresh($)
}

async function endSessionRuns($: EngineInterface): Promise<void> {
  const repo = await repoOf($)
  const runs = await readRuns($, repo.root)
  if (runs.length === 0) return
  await $.store.set(runsKey(repo.root), endRuns(runs, await $.session.id(), await $.clock.now()))
}

async function isPlanningFile($: EngineInterface, file: string): Promise<boolean> {
  const folders = await readFolders($, await repoOf($))
  return WORKFLOWS.some((w) => rootsFor(w, folders).some((root) => file.includes(`/${root}/`)))
}

async function trackEdit($: EngineInterface, file: string, before: string, after: string, known: Defs): Promise<void> {
  const oldDefs = defsIn(file, before)
  const newDefs = defsIn(file, after)
  const created = isSource(file) ? newDefs.filter((d) => !oldDefs.includes(d)) : []
  const removed = oldDefs.filter((d) => !newDefs.includes(d))
  const reused = isSource(file) ? callsIn(addedLines(before, after), known, newDefs) : []

  await setNumbers($, (n) => ({
    ...n,
    reused: union(n.reused, reused),
    created: union(n.created, created),
    removed: union(n.removed, removed),
    tests: isCode(file) && n.tests.state !== 'none' ? { ...n.tests, state: 'stale' } : n.tests,
  }))
}

// a removed or renamed definition that isn't defined again but still called somewhere
// shortcut: name match with git grep, so a same-named call in another module counts too
async function openCallers($: EngineInterface, removed: string[]): Promise<{ removed: string[]; openCallers: string[] }> {
  const stillRemoved: string[] = []
  const callers: string[] = []
  for (const name of removed) {
    const rows = hits((await gitGrep($, '-nw', '-e', name))?.stdout ?? '')
    if (rows.some((r) => defsIn(r.file, r.text.trimStart()).includes(name))) continue
    const call = new RegExp(`(?<![\\w$])${name.replace(/\$/g, '\\$')}\\s*\\(`)
    const refs = rows.filter((r) => call.test(r.text)).map((r) => `${r.file}:${r.line}`)
    if (refs.length === 0) continue
    stillRemoved.push(name)
    callers.push(...refs)
  }
  return { removed: stillRemoved, openCallers: callers }
}

export const register: Register = (on) => {
  let known: Defs = new Map()

  on('session.start', async ($, e, next) => {
    known = await start($, true)
    await $.command.register({ name: 'workflow-band', description: 'Hide or show the workflow band: /workflow-band off|on' }).catch(() => undefined)
    const hidden = (await $.store.get('hidden').catch(() => false)) === true
    await setUi($, (u) => ({ ...u, hidden }))
    await syncPane($)
    await refresh($)
    return next(e)
  }).catch(passOn)

  // /clear, /resume and /branch go on under another session id with an empty band and no session.start.
  // Only these commands: a hook on every command labels other plugins' command output with this plugin.
  on('command.run', { command: ['clear', 'resume', 'branch'] }, async ($, e, next) => {
    const session = await $.session.id()
    const result = await next(e)
    if ((await $.session.id()) !== session) {
      known = await start($, e.command !== 'clear').catch(() => known)
      await syncPane($)
      await refresh($)
    }
    return result
  }).catch(passOn)

  on('command.run', { command: 'workflow-band' }, async ($, e) => {
    const word = e.args?.trim()
    if (word && word !== 'on' && word !== 'off') return { text: 'Usage: /workflow-band off|on' }
    const hidden = word ? word === 'off' : !(await readUi($)).hidden
    await $.store.set('hidden', hidden)
    await setUi($, (u) => ({ ...u, hidden, paneOpen: hidden ? false : u.paneOpen }))
    if (hidden) await $.ui.close({ id: PANE }).catch(() => undefined)
    return { text: hidden ? 'Workflow band hidden. /workflow-band on brings it back.' : 'Workflow band shown.' }
  }).catch(passOn)

  // a turn still running counts as a conversation too: turns only rise at turn.complete
  on('prompt.submit', async ($, e, next) => {
    await setNumbers($, (n) => ({ ...n, talking: true }))
    return next(e)
  }).catch(passOn)

  on('skill.prompt', async ($, e, next) => {
    const result = await next(e)
    try {
      await setNumbers($, (n) => ({ ...n, talking: true }))
      await recordRun($, skillName(e.skill), argsOf(e.text))
    } catch (err) {
      logFailure($, 'recording a run', err)
    }
    return result
  }).catch(passOn)

  // the cost baseline stays
  on('session.end', async ($, e, next) => {
    await endSessionRuns($).catch((err) => logFailure($, 'ending runs', err))
    if (e.reason === 'clear') await setNumbers($, (n) => ({ ...n, ...TASK }))
    return next(e)
  }).catch(passOn)

  on('tool.call', async ($, e, next) => {
    if (e.tool === 'Bash') {
      const ran = await next(e)
      if (ran.deny === undefined && isTestCommand(e.command)) {
        const tests: Tests = { state: ran.isError ? 'fail' : 'pass', ...testCounts(ran.text ?? '') }
        await setNumbers($, (n) => ({ ...n, tests }))
      }
      return ran
    }

    if (e.tool !== 'Edit' && e.tool !== 'Write') return next(e)

    const file = e.file_path
    const planning = await isPlanningFile($, file)
    // a scratch script outside the project is never reused or called by it
    const tracked = inProject(file, await projectRoot($))
    const before = e.tool === 'Edit' ? e.old_string : tracked ? await $.fs.read(file).catch(() => '') : ''
    const after = e.tool === 'Edit' ? e.new_string : e.content

    const ran = await next(e)
    if (ran.deny !== undefined || ran.isError) return ran
    if (planning) await refresh($)
    if (tracked) await trackEdit($, file, before, after, known)
    return ran
  }).catch(passOn)

  on('turn.complete', async ($, e, next) => {
    const used = e.usage
    if (e.agentId !== undefined) {
      // a subagent's cost is already in the session cost the main turn reads, its tokens aren't
      if (used) await setNumbers($, (n) => ({ ...n, tokens: addTokens(n.tokens, used) }))
      return next(e)
    }

    const usage = await $.session.usage()
    const callers = await openCallers($, (await readNumbers($)).removed)

    await setNumbers($, (n) => {
      const cost = usage.cost?.usd ?? n.cost
      // a cost below the baseline means the engine started its ledger over
      const turn = cost >= n.cost ? cost - n.cost : cost
      return {
        ...n,
        ...callers,
        cost,
        spent: usage.cost?.usd ?? n.spent + turn,
        turns: n.turns + 1,
        turnCosts: [...n.turnCosts, turn].slice(-20),
        tokens: used ? addTokens(n.tokens, used) : n.tokens,
        busyMs: n.busyMs + e.durationMs,
      }
    })
    await refresh($)
    return next(e)
  }).catch(passOn)

  on('ui.close', { id: PANE }, async ($, e, next) => {
    await setUi($, (u) => ({ ...u, paneOpen: false }))
    return next(e)
  }).catch(passOn)

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => drawPane($, e, await drawState($))).catch(passOn)

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey || (await readUi($)).hidden) return next(e)
    // other mods share this slot and theirs goes below ours. next(e) rejects only when nothing answers beneath
    const below = await next(e).catch(() => undefined)
    return drawBand($, e, below, await drawState($))
  }).catch(passOn)
}
