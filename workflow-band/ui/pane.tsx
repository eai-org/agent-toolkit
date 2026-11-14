import type { EngineInterface, RenderElement, RenderInput } from 'claude-code'
import { openFile, runStep } from '../src/actions'
import { refresh, setUi } from '../src/state'
import type { Action, Numbers, Row, Shown, UiState } from '../types'
import { ICON, TONE } from './status'

// "123-x.PLAN.md" -> "PLAN.md"
const tail = (path: string) => path.split('/').pop()!.replace(/^[^.]*\.(?=[A-Z.-]+\.md$)/, '')

// how many of the plan tasks among the rows are done
const tally = (rows: Row[]) => {
  const tasks = rows.filter((r) => r.key.startsWith('task-'))
  return { done: tasks.filter((t) => t.status === 'done').length, total: tasks.length }
}

export async function drawPane($: EngineInterface, e: RenderInput<'Pane'>, s: { numbers: Numbers; shown: Shown | null; ui: UiState }): Promise<RenderElement> {
  const { Box, Text, Button, Progress } = $.ui.resolve(e)
  const shown = s.shown
  if (!shown) return <Text dimColor>No task under .agents/plans/ yet.</Text>

  const run = (a: Action) => runStep($, a, s.numbers.turns > 0 || s.numbers.talking).catch(() => $.ui.toast(`Could not run /${a.skill}`))
  const installed = (a: Action) => shown.installed.includes(a.skill)
  const cantSwitch = () => $.ui.toast('Could not switch the task')
  const togglePicker = () => setUi($, (u) => ({ ...u, picking: !u.picking })).catch(cantSwitch)
  const pick = (key: string) => setUi($, (u) => ({ ...u, pinned: key, picking: false })).then(() => refresh($)).catch(cantSwitch)

  const line = (r: Row, indent: number) => {
    const actions = r.status === 'done' ? [] : r.actions.filter(installed)
    const file = r.file
    return (
      <Box key={r.key} flexDirection="row" gap={1} paddingLeft={indent}>
        <Text wrap="truncate-end" color={TONE[r.status]} dimColor={r.status === 'todo' || r.status === 'unknown' || r.status === 'skipped'}>
          {ICON[r.status]} {r.label}
        </Text>
        {file && <Button key={`file-${r.key}`} plain label={tail(file)} onPress={() => openFile($, file)} />}
        {actions.map((a, i) => (
          <Button key={i ? `act-${r.key}-${i + 1}` : `act-${r.key}`} plain label={a.label} onPress={() => run(a)} />
        ))}
      </Box>
    )
  }

  // only the group being worked on lists its rows, the others show their count
  const groups = (rows: Row[]) => {
    const open = rows.find((g) => g.status === 'stopped' || g.status === 'current') ?? rows.find((g) => g.status !== 'done')
    return rows.flatMap((g) => {
      const inside = g.rows ?? []
      if (g === open) return [<Text key={g.key} wrap="truncate-end" bold color={TONE[g.status]}>{ICON[g.status]} {g.label}</Text>, ...inside.map((t) => line(t, 2))]
      const { done, total } = tally(inside)
      return [<Text key={g.key} wrap="truncate-end" color={TONE[g.status]} dimColor={g.status === 'todo'}>{ICON[g.status]} {g.label} {done}/{total}</Text>]
    })
  }

  const execute = (r: Row, groupRows: Row[]) => {
    const { done, total } = tally(groupRows.flatMap((g) => g.rows ?? []))
    return <Progress label={`${ICON[r.status]} ${r.label}`} value={done} max={total} valueText={`${done}/${total}`} color={TONE[r.status]} />
  }

  return (
    <Box flexDirection="column" width={e.props.bodyColumns}>
      <Box flexDirection="row" gap={1}>
        <Text color="claude">◆</Text>
        <Text bold wrap="truncate-end">{shown.name} · {shown.task.title}</Text>
        <Button key="pick" plain label="▾" onPress={togglePicker} />
      </Box>
      {s.ui.picking && shown.tasks.map((t) => <Button key={`task-${t.key}`} plain label={t.title} onPress={() => pick(t.key)} />)}
      {shown.view.rows.flatMap((r) => (r.key === 'execute' && r.rows ? [execute(r, r.rows), ...groups(r.rows)] : [line(r, 0)]))}
      {shown.view.other.map((f, i) => <Button key={`other-${i}`} plain label={tail(f)} onPress={() => openFile($, f)} />)}
    </Box>
  )
}
