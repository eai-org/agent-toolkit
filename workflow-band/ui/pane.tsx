import type { EngineInterface, RenderElement, RenderInput } from 'claude-code'
import { openFile, runStep } from '../src/actions'
import { refresh, setUi } from '../src/state'
import type { Action, Numbers, Row, Shown, Status, UiState } from '../types'

const ICON: Record<Status, string> = { done: '☑', current: '▣', todo: '☐', skipped: '☐', unknown: '?', stopped: '⚠' }
const TONE: Partial<Record<Status, 'success' | 'suggestion' | 'warning'>> = { done: 'success', current: 'suggestion', stopped: 'warning' }
const tail = (path: string) => path.split('/').pop()!.replace(/^[^.]*\.(?=[A-Z.-]+\.md$)/, '')

export async function drawPane($: EngineInterface, e: RenderInput<'Pane'>, s: { numbers: Numbers; shown: Shown | null; ui: UiState }): Promise<RenderElement> {
  const { Box, Text, Button, Progress } = $.ui.resolve(e)
  const shown = s.shown
  if (!shown) return <Text dimColor>No task under .agents/plans/ yet.</Text>

  const run = (a: Action) => runStep($, a, s.numbers.turns > 0 || s.numbers.talking).catch(() => $.ui.toast(`Could not run /${a.skill}`))
  const mine = (a: Action) => shown.installed.includes(a.skill)

  const line = (r: Row, indent: number) => {
    const actions = r.status === 'done' ? [] : r.actions.filter(mine)
    return (
      <Box key={r.key} flexDirection="row" gap={1} paddingLeft={indent}>
        <Text wrap="truncate-end" color={TONE[r.status]} dimColor={r.status === 'todo' || r.status === 'unknown' || r.status === 'skipped'}>
          {ICON[r.status]} {r.label}
        </Text>
        {r.file && <Button key={`file-${r.key}`} plain label={tail(r.file)} onPress={() => openFile($, r.file!)} />}
        {actions.map((a, i) => (
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
        return [<Text key={g.key} wrap="truncate-end" color={TONE[g.status]} dimColor={g.status === 'todo'}>{ICON[g.status]} {g.label} {tasks.filter((t) => t.status === 'done').length}/{tasks.length}</Text>]
      }
      return [<Text key={g.key} wrap="truncate-end" bold color={TONE[g.status]}>{ICON[g.status]} {g.label}</Text>, ...(g.rows ?? []).map((t) => line(t, 2))]
    })
  }

  const execute = (r: Row) => {
    const tasks = r.rows!.flatMap((g) => g.rows ?? []).filter((t) => t.key.startsWith('task-'))
    const done = tasks.filter((t) => t.status === 'done').length
    return <Progress label={`${ICON[r.status]} ${r.label}`} value={done} max={tasks.length} valueText={`${done}/${tasks.length}`} color={TONE[r.status]} />
  }

  const pick = (key: string) =>
    setUi($, (u) => ({ ...u, pinned: key, picking: false })).then(() => refresh($)).catch(() => $.ui.toast('Could not switch the task'))

  return (
    <Box flexDirection="column" width={e.props.bodyColumns}>
      <Box flexDirection="row" gap={1}>
        <Text color="claude">◆</Text>
        <Text bold wrap="truncate-end">{shown.name} · {shown.task.title}</Text>
        <Button key="pick" plain label="▾" onPress={() => setUi($, (u) => ({ ...u, picking: !u.picking })).catch(() => $.ui.toast('Could not switch the task'))} />
      </Box>
      {s.ui.picking && shown.tasks.map((t) => <Button key={`task-${t.key}`} plain label={t.title} onPress={() => pick(t.key)} />)}
      {shown.view.rows.flatMap((r) => (r.key === 'execute' && r.rows ? [execute(r), ...groups(r.rows)] : [line(r, 0)]))}
      {shown.view.other.map((f, i) => <Button key={`other-${i}`} plain label={tail(f)} onPress={() => openFile($, f)} />)}
    </Box>
  )
}
