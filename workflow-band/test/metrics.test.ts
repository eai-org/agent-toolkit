import { expect, test } from 'claude-code/testing'
import {
  NO_TOKENS, addTokens, addedLines, callsIn, defsIn, duration, elapsed, fmtTokens, inProject, isTestCommand,
  markdown, parseDefs, percent, testCounts, totalTokens, type Numbers,
} from '../src/metrics'

const BASE: Numbers = {
  cost: 31.9, spent: 3.1, turns: 6, turnCosts: [0.42], tokens: { input: 5000, output: 85_000, cacheRead: 1_100_000, cacheWrite: 10_000 },
  busyMs: 1_560_000, project: 'shop', session: '4c69e3db-57a0', reused: ['to_cents'], created: [],
  removed: [], openCallers: [], tests: { state: 'pass', passed: 14 },
}

test('adds up tokens and prints them short', () => {
  const t = addTokens(addTokens(NO_TOKENS, { input_tokens: 10, output_tokens: 90, cache_read_input_tokens: 1000, cache_creation_input_tokens: 0 }), { input_tokens: 0, output_tokens: 10, cache_read_input_tokens: 140, cache_creation_input_tokens: 0 })
  expect(totalTokens(t)).toBe(1250)
  expect(t.output).toBe(100)
  expect([fmtTokens(950), fmtTokens(1234), fmtTokens(1_240_000), fmtTokens(2000)]).toEqual(['950', '1.2k', '1.2M', '2k'])
})

test('agent time reads in seconds, minutes, hours', () => {
  expect([elapsed(45_000), elapsed(130_000), elapsed(4_320_000)]).toEqual(['45s', '2m 10s', '1h 12m'])
})

test('the Markdown export holds every value and the task name', () => {
  const md = markdown(BASE, '123-x', Date.UTC(2026, 9, 15, 12, 0))
  expect(md.split('\n')[0]).toBe('## 123-x')
  expect(md).toContain('| Cost | $3.10 · last turn $0.42 · ⌀ $0.52 / turn |')
  expect(md).toContain('| Agent time | 26m 0s · ⌀ 4m 20s / turn |')
  expect(md).toContain('| Tokens | 1.2M (input 5k, output 85k, cache read 1.1M, cache write 10k) |')
  expect(md).toContain('| Tests | 14 passed |')
  expect(md).not.toContain('level')
  expect(md).not.toContain('Model')
  expect(markdown(BASE, '', 0).split('\n')[0]).toBe('## Untitled session')
})

test('finds top-level definitions per language', () => {
  expect(defsIn('a.py', 'def to_cents(x):\n    pass\nclass Cart:\n    def total(self): pass')).toEqual(['to_cents', 'Cart'])
  expect(defsIn('a.ts', 'export function formatMoney() {}\nfunction local() {}\nconst x = 1')).toEqual(['formatMoney', 'local'])
  expect(defsIn('README.md', 'def nope():')).toEqual([])
})

test('counts calls of existing helpers, never new ones, test files or generic names', () => {
  const known = parseDefs('utils/money.py:4:def to_cents(v):\nutils/io.py:1:def load(p):\ntests/test_x.py:1:def helper():')
  expect([...known.keys()]).toEqual(['to_cents', 'load'])
  const added = addedLines('x = 1', 'x = 1\ny = to_cents(p)\nz = load(f)\nw = parse_price(s)')
  expect(added).not.toContain('x = 1')
  expect(callsIn(added, known, ['parse_price'])).toEqual(['to_cents'])
})

test('only files under the project root count, with either slash', () => {
  expect(inProject('/repo/shop/cart.py', '/repo/shop')).toBe(true)
  expect(inProject('/repo/shop/cart.py', '/repo/shop/')).toBe(true)
  expect(inProject('/tmp/scratch/drive.py', '/repo/shop')).toBe(false)
  expect(inProject('/repo/shop-old/cart.py', '/repo/shop')).toBe(false)
  expect(inProject('C:\\Users\\a\\shop\\cart.py', 'C:/Users/a/shop')).toBe(true)
})

test('recognises test runs and their counts', () => {
  expect(isTestCommand('npm test')).toBe(true)
  expect(isTestCommand('cd api && python -m pytest -q')).toBe(true)
  expect(isTestCommand('npm install')).toBe(false)
  expect(testCounts('===== 14 passed, 1 failed in 0.31s =====')).toEqual({ passed: 14, failed: 1 })
  expect(testCounts('ℹ pass 141\nℹ fail 1')).toEqual({ passed: 141, failed: 1 })
  expect(testCounts('ok')).toEqual({ passed: undefined, failed: undefined })
})

test('shows the reuse share only once there is something to share, and a readable time', () => {
  expect(percent(5, 1)).toBe(83)
  expect(percent(0, 1)).toBeUndefined()
  expect(percent(0, 0)).toBeUndefined()
  expect(duration(45)).toBe('45m')
  expect(duration(210)).toBe('3h 30m')
})
