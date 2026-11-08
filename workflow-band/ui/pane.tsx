import type { EngineInterface, RenderElement, RenderInput } from 'claude-code'
import { openFile, runStep } from '../src/actions'
import { refresh, setUi } from '../src/state'
import type { Action, Numbers, Row, Shown, Status, UiState } from '../types'

const ICON: Record<Status, string> = { done: '✓', current: '◉', todo: '○', skipped: '○', unknown: '?', stopped: '⚠' }
const tail = (path: string) => path.split('/').pop()!.replace(/^.*?\.(?=[A-Z-]+\.md$)/, '')

export async function drawPane($: EngineInterface, e: RenderInput<'Pane'>, s: { numbers: Numbers; shown: Shown | null; ui: UiState }): Promise<RenderElement> {
  const { Box, Text, Button } = $.ui.resolve(e)
  const shown = s.shown
  if (!shown) return <Text dimColor>No task under .agents/plans/ yet.</Text>

  const run = (a: Action) => runStep($, a, s.numbers.turns > 0).catch(() => $.ui.toast(`Could not run /${a.skill}`))
  const mine = (a: Action) => shown.installed.includes(a.skill)

  const line = (r: Row, indent: number) => {
    const actions = r.actions.filter(mine)
    const shownActions = r.status === 'stopped' ? actions : actions.slice(0, 1)
    return (
      <Box key={r.key} flexDirection="row" gap={1} paddingLeft={indent}>
        <Text wrap="truncate-end" color={r.status === 'current' ? 'suggestion' : r.status === 'stopped' ? 'warning' : undefined} dimColor={r.status === 'todo' || r.status === 'unknown' || r.status === 'skipped'}>
          {ICON[r.status]} {r.label}{r.hardened ? ' ⛨' : ''}
        </Text>
        {r.file && <Button key={`file-${r.key}`} plain label={tail(r.file)} onPress={() => openFile($, r.file!)} />}
        {shownActions.map((a, i) => (
          <Button key={i ? `act-${r.key}-${i + 1}` : `act-${r.key}`} plain label={a.label} onPress={() => run(a)} />
        ))}
      </Box>
    )
  }

  const groups = (rows: Row[]) => {
    const open = rows.find((g) => g.status === 'stopped' || g.status === 'current') ?? rows.find((g) => g.status !== 'done')
    return rows.flatMap((g) => {
      if (g !== open) {
        const tasks = (g.rows ?? []).filter((t) => t.key.startsWith('task-'))
        return [<Text key={g.key} wrap="truncate-end">{ICON[g.status]} {g.label} {tasks.filter((t) => t.status === 'done').length}/{tasks.length}</Text>]
      }
      return [<Text key={g.key} wrap="truncate-end" bold>{ICON[g.status]} {g.label}</Text>, ...(g.rows ?? []).map((t) => line(t, 2))]
    })
  }

  const title = `${shown.name} · ${shown.task.title}`
  const pick = (key: string) =>
    setUi($, (u) => ({ ...u, pinned: key, picking: false })).then(() => refresh($))

  return (
    <Box flexDirection="column" width={e.props.bodyColumns}>
      <Box flexDirection="row" gap={1}>
        <Text bold wrap="truncate-end">{title}</Text>
        <Button key="pick" plain label="▾" onPress={() => setUi($, (u) => ({ ...u, picking: !u.picking }))} />
      </Box>
      {s.ui.picking && shown.tasks.map((t) => <Button key={`task-${t.key}`} plain label={t.title} onPress={() => pick(t.key)} />)}
      {shown.view.rows.flatMap((r) => (r.key === 'execute' && r.rows ? [<Text key="execute" wrap="truncate-end">{ICON[r.status]} {r.label}</Text>, ...groups(r.rows)] : [line(r, 0)]))}
      {shown.view.other.map((f, i) => <Button key={`other-${i}`} plain label={tail(f)} onPress={() => openFile($, f)} />)}
    </Box>
  )
}
