import type { EngineInterface } from 'claude-code'
import type { Action } from './workflow'

export const CLEAR_FIRST = 'Clear first, then run (Recommended)', RUN_HERE = 'Run here', CANCEL = 'Cancel'

export async function commandName($: EngineInterface, skill: string): Promise<string | undefined> {
  const names = (await $.command.list()).map((c) => c.name)
  return names.find((n) => n === skill) ?? names.find((n) => n.endsWith(`:${skill}`))
}

export async function runStep($: EngineInterface, action: Action, hasConversation: boolean): Promise<void> {
  const name = await commandName($, action.skill)
  if (!name) return $.ui.toast(`${action.skill} isn't installed`)
  const run = () => $.command.run({ command: name, args: action.args })
  if (!hasConversation) return void (await run())
  const answer = await $.ui.ask(`Run /${name} ${action.args}: clear this session first, or run it here?`, [CLEAR_FIRST, RUN_HERE, CANCEL]).catch(() => CANCEL)
  if (answer === CLEAR_FIRST) await $.command.run({ command: 'clear' })
  if (answer === CLEAR_FIRST || answer === RUN_HERE) await run()
}

export async function openFile($: EngineInterface, path: string): Promise<void> {
  const windows = (await $.env.get('OS')) === 'Windows_NT'
  try {
    const mac = !windows && (await $.process.run(['uname'])).stdout.trim() === 'Darwin'
    const r = await $.process.run(windows ? ['cmd', '/c', 'start', '', path] : [mac ? 'open' : 'xdg-open', path])
    if (r.exitCode !== 0) throw new Error(r.stderr)
  } catch {
    $.ui.toast(`Could not open ${path}`)
  }
}
