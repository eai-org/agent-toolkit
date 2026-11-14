import type { EngineInterface, RenderElement, RenderInput } from 'claude-code'
import { errorText, openFile, runStep } from '../src/actions'
import { PANE, setUi } from '../src/state'
import { elapsed, fmtTokens, markdown, percent, totalTokens } from '../src/metrics'
import type { CompactItem, Numbers, Shown, Tests, UiState } from '../types'
import { ICON, TONE } from './status'

type Piece = { text: string; item?: CompactItem }

const cells = (pieces: Piece[]) => pieces.reduce((n, p) => n + p.text.length, 0)

// short: a done step is only its icon
const pieces = (s: Shown, short: boolean): Piece[] => [
  { text: '◆ ' },
  { text: `${s.name} ` },
  ...s.view.compact.flatMap((item, i) => {
    const text = short && item.status === 'done' ? ICON.done : `${ICON[item.status]} ${item.label}`
    return [...(i ? [{ text: ' ─ ' }] : []), { text, item }]
  }),
]

// the piece crossing the edge ends in an ellipsis, the rest are dropped
function fit(row: Piece[], room: number): Piece[] {
  const out: Piece[] = []
  for (const p of row) {
    if (room <= 0) break
    const text = p.text.length > room ? `${p.text.slice(0, room - 1)}…` : p.text
    out.push({ ...p, text })
    room -= text.length
  }
  return out
}

// the full row when it fits, else the short one, cut at the edge when even that is too wide
function layout(shown: Shown, room: number | undefined): Piece[] {
  const full = pieces(shown, false)
  if (room === undefined || cells(full) <= room) return full
  const short = pieces(shown, true)
  return cells(short) <= room ? short : fit(short, room)
}

const TESTS_TEXT: Record<Tests['state'], (t: Tests) => string> = {
  pass: (t) => `✓ ${t.passed ?? ''} tests`,
  fail: (t) => `✗ ${t.failed ?? ''} failed`,
  stale: () => 'no test since change',
  none: () => '',
}
const TESTS_COLOR: Partial<Record<Tests['state'], 'success' | 'error'>> = { pass: 'success', fail: 'error' }

export async function drawBand($: EngineInterface, e: RenderInput<'AbovePrompt'>, below: RenderElement | undefined, s: { numbers: Numbers; shown: Shown | null; ui: UiState }): Promise<RenderElement> {
  const { Box, Text, Button } = $.ui.resolve(e)
  const n = s.numbers
  const startedAt = (await $.session.usage().catch(() => undefined))?.startedAt ?? (await $.clock.now())
  // bodyColumns counts terminal cells, a graphical surface draws Buttons wider than that
  const width = e.surface === 'terminal' ? e.props.bodyColumns : undefined

  const copy = () =>
    $.ui.copy({ text: markdown(n, s.shown?.task.title ?? '', startedAt), surface: e.surface }).then(
      (r) => $.ui.toast(r.isCopied ? 'Task copied as Markdown' : `Copy failed: ${r.reason}`),
      (err: unknown) => $.ui.toast(`Copy failed: ${errorText(err)}`),
    )
  const expand = async () => {
    const title = `${s.shown!.name} · ${s.shown!.task.title}`
    try {
      const r = await $.ui.open({ id: PANE, title })
      if (r.isPlaced) await setUi($, (u) => ({ ...u, paneOpen: true }))
      else $.ui.toast(`Could not open the pane: ${r.reason}`)
    } catch {
      $.ui.toast('Could not open the pane')
    }
  }
  const compact = async () => {
    try {
      await $.ui.close({ id: PANE })
      await setUi($, (u) => ({ ...u, paneOpen: false }))
    } catch {
      $.ui.toast('Could not close the pane')
    }
  }

  // the open pane shows the steps itself
  const shown = s.ui.paneOpen ? null : s.shown
  const next = shown?.view.next
  // while a turn runs, the next step is the one running
  const run = next && shown.installed.includes(next.skill) && !e.props.isWorking ? next : undefined
  const end = shown?.view.stopped ? `⚠ task ${shown.view.stopped} stopped` : run ? `▶ Run ${run.label}` : ''
  const room = width === undefined ? undefined : width - (end ? end.length + 1 : 0)
  const row = shown ? layout(shown, room) : []

  const piece = ({ text, item }: Piece, i: number) => {
    const hover = item?.skill ? { scope: `skill-${item.key}` } : undefined
    const file = item?.file
    if (item?.status === 'done' && file)
      return <Button key={`item-${item.key}`} plain label={text} hover={hover} onPress={() => openFile($, file)}><Text color="success">{text}</Text></Button>
    if (item?.status === 'stopped')
      return <Button key={`item-${item.key}`} plain label={text} hover={hover} onPress={() => expand()}><Text color="warning">{text}</Text></Button>
    // pieces 0 and 1 are the diamond and the workflow name
    return (
      <Text
        wrap="truncate-end"
        bold={i === 1}
        color={i === 0 ? 'claude' : item && TONE[item.status]}
        dimColor={item ? item.status === 'todo' || item.status === 'unknown' : i > 1}
        hover={hover}
      >
        {text}
      </Text>
    )
  }

  const steps = shown && (
    <Box key="steps" flexDirection="row" width={width}>
      {row.map(piece)}
      <Box flexGrow={1} minWidth={end ? 1 : 0} />
      {shown.view.stopped ? (
        <Text color="warning">{end}</Text>
      ) : (
        run && <Button key="run" plain label={end} onPress={() => runStep($, run, n.turns > 0 || n.talking).catch(() => $.ui.toast(`Could not run /${run.skill}`))} />
      )}
    </Box>
  )
  // shown over the numbers row while its step is hovered
  const skills = row.flatMap(({ item }) =>
    item?.skill ? [<Box position="absolute" top={1} left={0} display="none" hover={{ display: 'flex', scope: `skill-${item.key}` }}><Text dimColor>/{item.skill}</Text></Box>] : [],
  )

  const reuse = percent(n.reused.length, n.created.length)
  const last = n.turnCosts[n.turnCosts.length - 1]
  const tests = TESTS_TEXT[n.tests.state](n.tests)

  const mine = (
    <Box flexDirection="column" width={width}>
      {steps}
      <Box flexDirection="row" alignItems="center" gap={2}>
        <Text>${n.spent.toFixed(2)}</Text>
        {last !== undefined && <Text dimColor>last ${last.toFixed(2)}</Text>}
        <Text dimColor>{fmtTokens(totalTokens(n.tokens))} tokens</Text>
        <Text dimColor>{n.turns} {n.turns === 1 ? 'turn' : 'turns'}</Text>
        <Text dimColor>{elapsed(n.busyMs)}</Text>
        {reuse !== undefined && <Text>{reuse}% reuse</Text>}
        {n.openCallers.length > 0 && <Text color="warning">⚠ {n.openCallers.length} callers open</Text>}
        {tests !== '' && <Text color={TESTS_COLOR[n.tests.state]} dimColor={n.tests.state === 'stale'}>{tests}</Text>}
        <Box flexGrow={1} />
        {s.shown && (s.ui.paneOpen ? <Button key="compact" plain label="Compact" onPress={compact} /> : <Button key="expand" plain label="Expand" onPress={expand} />)}
        <Button key="copy" plain label="Copy" onPress={copy} />
      </Box>
      {skills}
    </Box>
  )
  return below ? <Box flexDirection="column">{mine}{below}</Box> : mine
}
