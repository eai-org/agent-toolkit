import { expect, test } from 'claude-code/testing'
import { addRun, argsOf, endRuns, RUNS_CAP, runsKey, skillName } from '../src/runs'
import { pickTask } from '../src/pick'
import type { Run, Task } from '../src/workflow'

const run = (o: Partial<Run>): Run => ({ skill: 's', args: '', task: 'A', at: 1, session: 's1', checkout: '/w1', ...o })
const task = (key: string, mtimeMs: number): Task => ({ key, title: key, files: [], mtimeMs })

test('argsOf reads the last ARGUMENTS line', () => {
  expect(argsOf('text\n\nARGUMENTS: .agents/plans/a/a.PLAN.md 2.2')).toBe('.agents/plans/a/a.PLAN.md 2.2')
  expect(argsOf('ARGUMENTS: x ')).toBe('x')
  expect(argsOf('a\nARGUMENTS: one\nmore\nARGUMENTS: two')).toBe('two')
  expect(argsOf('no args here')).toBe('')
})

test('skillName strips the plugin prefix, runsKey builds the key', () => {
  expect(skillName('agent-toolkit:self-review')).toBe('self-review')
  expect(skillName('plain')).toBe('plain')
  expect(runsKey('r')).toBe('runs:r')
})

test('addRun keeps the newest RUNS_CAP', () => {
  let runs: Run[] = []
  for (let i = 0; i < RUNS_CAP + 5; i++) runs = addRun(runs, run({ at: i }))
  expect(runs.length).toBe(RUNS_CAP)
  expect(runs[runs.length - 1]!.at).toBe(RUNS_CAP + 4)
})

test('endRuns ends only open runs of the session', () => {
  const runs = [run({}), run({ endedAt: 5 }), run({ session: 's2' })]
  const out = endRuns(runs, 's1', 9)
  expect(out.map((r) => r.endedAt)).toEqual([9, 5, undefined])
  expect(runs[0]!.endedAt).toBe(undefined)
})

test('pickTask order', () => {
  const tasks = [task('A', 3), task('B', 2), task('C', 1)]
  const runs = [run({ task: 'B', session: 's1', checkout: '/w1', at: 1 }), run({ task: 'C', session: 's2', checkout: '/w2', at: 2 })]
  const key = (w: Parameters<typeof pickTask>[2], r = runs, t = tasks) => pickTask(t, r, w)?.key
  expect(key({ session: 's1', checkout: '/w1' })).toBe('B')
  expect(key({ session: 's9', checkout: '/w1' })).toBe('B')
  expect(key({ session: 's9', checkout: '/w9' })).toBe('C')
  expect(key({ session: 's9', checkout: '/w9' }, [])).toBe('A')
  expect(key({ session: 's1', checkout: '/w1', pinned: 'C' })).toBe('C')
  expect(key({ session: 's1', checkout: '/w1', pinned: 'gone' }, [])).toBe('A')
  expect(key({ session: 's1', checkout: '/w1' }, runs, [])).toBe(undefined)
  expect(key({ session: 's1', checkout: '/w1' }, [run({ task: 'gone', at: 9 }), run({ task: 'C', at: 1 })])).toBe('C')
})
