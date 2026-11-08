import { expect, test } from 'claude-code/testing'
import { parseTasks } from '../workflows/rpac/plan'

const PLAN = [
  '# Plan', '## Acceptance criteria', '- [ ] AC-1 a', '- [x] AC-2 b', '## Tasks',
  '### Group 1 — Approval API', '- *Depends on* nothing', '- [x] **1.1 Add endpoint** — steps 1–2', '  - *Done when* x',
  '- [X] **1.2 Add tests** — step 3', '### Group 2 - Approval screen', '- [x] **2.1 Add approve button** — step 4',
  '- [ ] **2.2 Add reject dialog** — step 5', '- [ ] **2.3 Show status badge** — step 6', '## Notes', '- [ ] not a task',
].join('\n')

test('reads groups and ticks from the Tasks section only', async () => {
  expect(parseTasks(PLAN)).toEqual([
    { n: 1, title: 'Approval API', tasks: [{ id: '1.1', title: 'Add endpoint', done: true }, { id: '1.2', title: 'Add tests', done: true }] },
    { n: 2, title: 'Approval screen', tasks: [
      { id: '2.1', title: 'Add approve button', done: true },
      { id: '2.2', title: 'Add reject dialog', done: false },
      { id: '2.3', title: 'Show status badge', done: false },
    ] },
  ])
})

test('a plan without a Tasks section is not split', async () => {
  expect(parseTasks('# Plan\n- [ ] AC-1 a\n')).toBeUndefined()
})
