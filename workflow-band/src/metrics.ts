export type Tokens = { input: number; output: number; cacheRead: number; cacheWrite: number }

export type Tests = {
  state: 'none' | 'pass' | 'fail' | 'stale'
  passed?: number
  failed?: number
}

export type Numbers = { cost: number; spent: number; turns: number; turnCosts: number[]; tokens: Tokens; busyMs: number; project: string; session: string; reused: string[]; created: string[]; removed: string[]; openCallers: string[]; tests: Tests }

export const duration = (minutes: number) =>
  minutes < 60 ? `${minutes}m` : `${Math.floor(minutes / 60)}h ${minutes % 60}m`

export const elapsed = (ms: number) => {
  const s = Math.round(ms / 1000)
  if (s < 60) return `${s}s`
  if (s < 3600) return `${Math.floor(s / 60)}m ${s % 60}s`
  return duration(Math.round(s / 60))
}

export const fmtTokens = (n: number) =>
  n < 1000 ? `${n}` : n < 1e6 ? `${+(n / 1e3).toFixed(1)}k` : `${+(n / 1e6).toFixed(1)}M`

const SKIP_DIR = /(^|\/)(node_modules|\.git|dist|build|out|vendor|venv|\.venv|__pycache__|coverage|\.next|target|migrations|fixtures|tests?|__tests__|spec)(\/|$)/
const SKIP_FILE = /(^|\/)(test_[^/]*|[^/]*(_test|\.test|\.spec|\.gen|\.min|\.d)\.[a-z]+)$/

// Regexes, not a parser: nested and dynamic definitions are missed.
const DEFS: [RegExp, RegExp[]][] = [
  [/\.py$/, [/^(?:async\s+)?def\s+([A-Za-z]\w*)/gm, /^class\s+([A-Za-z]\w*)/gm]],
  [/\.[cm]?[jt]sx?$/, [
    /^export\s+(?:default\s+)?(?:async\s+)?(?:function\*?|class|const|let|var)\s+([A-Za-z_$][\w$]*)/gm,
    /^(?:async\s+)?function\*?\s+([A-Za-z_$][\w$]*)/gm,
  ]],
  [/\.go$/, [/^func\s+(?:\([^)]*\)\s*)?([A-Za-z]\w*)/gm]],
  [/\.rs$/, [/^(?:pub\s+)?(?:async\s+)?fn\s+(\w+)/gm]],
  [/\.rb$/, [/^\s*def\s+(?:self\.)?([A-Za-z]\w*[?!]?)/gm]],
]

export const GREP_DEFS = '^[[:space:]]*(export|async|def|class|function|func|pub|fn)[[:space:]]'

const GENERIC = new Set(['main', 'init', 'run', 'get', 'set', 'test', 'setup', 'open', 'close', 'read', 'write', 'start', 'stop', 'load', 'save', 'update', 'create', 'delete', 'handle', 'render', 'index', 'new', 'call', 'apply'])

export const isCode = (file: string) => DEFS.some(([ext]) => ext.test(file))

export const isSource = (file: string) => isCode(file) && !SKIP_DIR.test(file) && !SKIP_FILE.test(file)

export function defsIn(file: string, text: string): string[] {
  const rules = DEFS.find(([ext]) => ext.test(file))?.[1] ?? []
  const names = new Set<string>()
  for (const re of rules) for (const m of text.matchAll(re)) if (m[1]) names.add(m[1])
  return [...names]
}

export type Hit = { file: string; line: string; text: string }

// `git grep -n` output, one "file:line:text" row each.
export const hits = (stdout: string): Hit[] =>
  stdout.split('\n').flatMap(row => {
    const m = /^(.+?):(\d+):(.*)$/.exec(row)
    return m ? [{ file: m[1] ?? '', line: m[2] ?? '', text: m[3] ?? '' }] : []
  })

// name -> "file:line"
export function parseDefs(stdout: string): Map<string, string> {
  const known = new Map<string, string>()
  for (const hit of hits(stdout)) {
    if (!isSource(hit.file)) continue
    for (const name of defsIn(hit.file, hit.text.trimStart())) {
      if (!known.has(name)) known.set(name, `${hit.file}:${hit.line}`)
    }
  }
  return known
}

export function addedLines(before: string, after: string): string {
  const old = new Set(before.split('\n'))
  return after.split('\n').filter(line => !old.has(line)).join('\n')
}

export function callsIn(text: string, known: Map<string, string>, own: string[]): string[] {
  const names = new Set<string>()
  for (const m of text.matchAll(/(?<![\w$])([A-Za-z_$][\w$]*)\s*\(/g)) {
    const name = m[1] ?? ''
    if (known.has(name) && !own.includes(name) && !GENERIC.has(name.toLowerCase())) names.add(name)
  }
  return [...names]
}

// Windows paths may use either slash.
export function inProject(file: string, root: string): boolean {
  const f = file.replace(/\\/g, '/')
  const r = root.replace(/\\/g, '/').replace(/\/+$/, '')
  return f === r || f.startsWith(`${r}/`)
}

const TEST_CMD = /\b(npm (run )?test|pnpm (run )?test|yarn test|bun test|npx (jest|vitest)|jest|vitest|pytest|python3? -m pytest|go test|cargo test|mvn test|gradle test|rspec|phpunit|dotnet test|node --test|deno test|make test)\b/

export const isTestCommand = (command: string) => TEST_CMD.test(command)

// Pass and fail counts from pytest, jest/vitest, cargo, node --test and TAP.
export function testCounts(output: string): { passed?: number; failed?: number } {
  const num = (re: RegExp) => {
    const m = re.exec(output)
    return m ? Number(m[1]) : undefined
  }
  return {
    passed: num(/(\d+) (?:passed|passing)\b/) ?? num(/(?:ℹ |# )pass (\d+)/),
    failed: num(/(\d+) (?:failed|failing)\b/) ?? num(/(?:ℹ |# )fail (\d+)/),
  }
}

export const NO_TOKENS: Tokens = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }

type Usage = { input_tokens: number; output_tokens: number; cache_read_input_tokens: number; cache_creation_input_tokens: number }

export const addTokens = (t: Tokens, u: Usage): Tokens => ({
  input: t.input + u.input_tokens,
  output: t.output + u.output_tokens,
  cacheRead: t.cacheRead + u.cache_read_input_tokens,
  cacheWrite: t.cacheWrite + u.cache_creation_input_tokens,
})

export const totalTokens = (t: Tokens) => t.input + t.output + t.cacheRead + t.cacheWrite

const stamp = (ms: number) => {
  const d = new Date(ms)
  const two = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())} ${two(d.getHours())}:${two(d.getMinutes())}`
}

export const testsLabel = (t: Tests) =>
  t.state === 'pass' ? `${t.passed ?? ''} passed`.trim() : t.state === 'fail' ? `${t.failed ?? ''} failed`.trim() : t.state === 'stale' ? 'stale' : 'not run'

const per = (total: number, n: number) => (n > 0 ? total / n : 0)

// Below 3 functions one new helper would read as 0% reuse, so no share is shown.
export const percent = (reused: number, created: number) =>
  reused + created < 3 ? undefined : Math.round((reused / (reused + created)) * 100)

export function markdown(n: Numbers, title: string, startedAt: number): string {
  const t = n.tokens
  const reuse = percent(n.reused.length, n.created.length)
  const last = n.turnCosts[n.turnCosts.length - 1]
  const rows = [
    ['Project', n.project],
    ['Started', stamp(startedAt)],
    ['Cost', `$${n.spent.toFixed(2)}${last === undefined ? '' : ` · last turn $${last.toFixed(2)}`} · ⌀ $${per(n.spent, n.turns).toFixed(2)} / turn`],
    ['Turns', `${n.turns}`],
    ['Agent time', `${elapsed(n.busyMs)} · ⌀ ${elapsed(per(n.busyMs, n.turns))} / turn`],
    ['Tokens', `${fmtTokens(totalTokens(t))} (input ${fmtTokens(t.input)}, output ${fmtTokens(t.output)}, cache read ${fmtTokens(t.cacheRead)}, cache write ${fmtTokens(t.cacheWrite)})`],
    ['Reuse', `${reuse === undefined ? '–' : `${reuse}%`} (${n.reused.length} used, ${n.created.length} new)`],
    ['Callers open', `${n.openCallers.length}`],
    ['Tests', testsLabel(n.tests)],
    ['Session', `\`${n.session}\``],
  ]
  const cell = (v: string) => v.replace(/\|/g, '\\|')
  return [`## ${cell(title || 'Untitled session')}`, '', '| | |', '|---|---|', ...rows.map(([k, v]) => `| ${k} | ${cell(v ?? '')} |`)].join('\n')
}
