import type { EngineInterface } from 'claude-code'
import type { Action } from './workflow'

export const CLEAR_FIRST = 'Clear first, then run (Recommended)', RUN_HERE = 'Run here', CANCEL = 'Cancel'

export const nameIn = (names: string[], skill: string): string | undefined =>
  names.find((n) => n === skill) ?? names.find((n) => n.endsWith(`:${skill}`))

export async function commandName($: EngineInterface, skill: string): Promise<string | undefined> {
  return nameIn((await $.command.list()).map((c) => c.name), skill)
}

export async function runStep($: EngineInterface, action: Action, hasConversation: boolean): Promise<void> {
  const name = await commandName($, action.skill)
  if (!name) return $.ui.toast(`${action.skill} isn't installed`)
  const run = () => $.command.run({ command: name, args: action.args })
  if (!hasConversation) return void (await run())
  const answer = await $.ui.ask(`Run /${name}${action.args ? ` ${action.args}` : ''}: clear this session first, or run it here?`, [CLEAR_FIRST, RUN_HERE, CANCEL]).catch(() => CANCEL)
  if (answer === CLEAR_FIRST) await $.command.run({ command: 'clear' })
  if (answer === CLEAR_FIRST || answer === RUN_HERE) await run()
}

export const vscodeLink = (path: string): string => `vscode://file${encodeURI(path.replace(/\\/g, '/').replace(/^\/?/, '/'))}`

export async function openFile($: EngineInterface, path: string): Promise<void> {
  try {
    const windows = (await $.env.get('OS')) === 'Windows_NT'
    const mac = !windows && (await $.process.run(['uname'])).stdout.trim() === 'Darwin'
    const open = (target: string) =>
      $.process.run(windows ? ['cmd', '/c', 'start', '', target] : [mac ? 'open' : 'xdg-open', target]).then((r) => r.exitCode === 0, () => false)
    // the link needs no `code` CLI on PATH
    if ((await $.env.get('TERM_PROGRAM')) === 'vscode' && (await open(vscodeLink(path)))) return
    if (!(await open(path))) throw new Error(path)
  } catch {
    $.ui.toast(`Could not open ${path}`)
  }
}
