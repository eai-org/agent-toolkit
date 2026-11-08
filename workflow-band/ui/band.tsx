import type { EngineInterface, RenderElement, RenderInput } from 'claude-code'
import { openFile, runStep } from '../src/actions'
import { PANE, setUi } from '../src/state'
import { elapsed, fmtTokens, markdown, percent, totalTokens } from '../src/metrics'
import type { CompactItem, Numbers, Shown, Status, UiState } from '../types'

const ICON: Record<Status, string> = { done: '✓', current: '◉', todo: '○', skipped: '○', unknown: '?', stopped: '⚠' }

type Piece = { text: string; item?: CompactItem }

const cells = (pieces: Piece[]) => pieces.reduce((n, p) => n + p.text.length, 0)

const pieces = (s: Shown, short: boolean): Piece[] => [
  { text: `${s.name} ` },
  ...s.view.compact.flatMap((item, i) => {
    const text = short && item.status === 'done' ? ICON.done : `${ICON[item.status]} ${item.label}${item.hardened ? ' ⛨' : ''}`
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

export async function drawBand($: EngineInterface, e: RenderInput<'AbovePrompt'>, below: RenderElement | undefined, s: { numbers: Numbers; shown: Shown | null; ui: UiState }): Promise<RenderElement> {
  const { Box, Text, Button } = $.ui.resolve(e)
  const n = s.numbers
  const startedAt = (await $.session.usage().catch(() => undefined))?.startedAt ?? (await $.clock.now())
  // bodyColumns counts terminal cells, a graphical surface draws Buttons wider than that
  const width = e.surface === 'terminal' ? e.props.bodyColumns : undefined

  const shown = s.ui.paneOpen ? null : s.shown
  const next = shown?.view.next
  const run = next && shown.installed.includes(next.skill) ? next : undefined
  const end = shown?.view.stopped ? `⚠ task ${shown.view.stopped} stopped` : run ? `▶ Run ${run.label}` : ''
  let row = shown ? pieces(shown, false) : []
  if (shown && width !== undefined) {
    const room = width - (end ? end.length + 1 : 0)
    if (cells(row) > room) row = pieces(shown, true)
    if (cells(row) > room) row = fit(row, room)
  }
  const scope = (item?: CompactItem) => (item?.skill ? { scope: `skill-${item.key}` } : undefined)

  const steps = shown && (
    <Box key="steps" flexDirection="row" width={width}>
      {row.map(({ text, item }, i) =>
        item?.status === 'done' && item.file ? (
          <Button key={`item-${item.key}`} plain label={text} hover={scope(item)} onPress={() => openFile($, item.file!)} />
        ) : (
          <Text
            wrap="truncate-end"
            bold={i === 0}
            color={item?.status === 'current' ? 'suggestion' : item?.status === 'stopped' ? 'warning' : undefined}
            dimColor={item ? item.status === 'todo' || item.status === 'unknown' : i > 0}
            hover={scope(item)}
          >
            {text}
          </Text>
        ),
      )}
      <Box flexGrow={1} minWidth={end ? 1 : 0} />
      {shown.view.stopped ? (
        <Text color="warning">{end}</Text>
      ) : (
        run && <Button key="run" plain label={end} onPress={() => runStep($, run, n.turns > 0).catch(() => $.ui.toast(`Could not run /${run.skill}`))} />
      )}
    </Box>
  )
  // shown over the numbers row while its step is hovered
  const skills = row.flatMap(({ item }) =>
    item?.skill ? [<Box position="absolute" top={1} left={0} display="none" hover={{ display: 'flex', scope: `skill-${item.key}` }}><Text dimColor>/{item.skill}</Text></Box>] : [],
  )

  const reuse = percent(n.reused.length, n.created.length)
  const last = n.turnCosts[n.turnCosts.length - 1]
  const tests = n.tests.state === 'pass' ? `✓ ${n.tests.passed ?? ''} tests` : n.tests.state === 'fail' ? `✗ ${n.tests.failed ?? ''} failed` : n.tests.state === 'stale' ? 'no test since change' : ''
  const copy = () =>
    $.ui.copy({ text: markdown(n, s.shown?.task.title ?? '', startedAt), surface: e.surface }).then(
      (r) => $.ui.toast(r.isCopied ? 'Task copied as Markdown' : `Copy failed: ${r.reason}`),
      (err: unknown) => $.ui.toast(`Copy failed: ${err instanceof Error ? err.message : String(err)}`),
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
        {tests !== '' && (
          <Text color={n.tests.state === 'pass' ? 'success' : n.tests.state === 'fail' ? 'error' : undefined} dimColor={n.tests.state === 'stale'}>
            {tests}
          </Text>
        )}
        <Box flexGrow={1} />
        {s.shown && (s.ui.paneOpen ? <Button key="compact" plain label="Compact" onPress={compact} /> : <Button key="expand" plain label="Expand" onPress={expand} />)}
        <Button key="copy" plain label="Copy" onPress={copy} />
      </Box>
      {skills}
    </Box>
  )
  return below ? <Box flexDirection="column">{mine}{below}</Box> : mine
}
