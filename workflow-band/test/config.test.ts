import { expect, test } from 'claude-code/testing'
import { parseConfig, rootsFor } from '../src/config'
import { WORKFLOWS } from '../workflows'

const rpac = WORKFLOWS.find((w) => w.id === 'rpac')!

test('parseConfig reads the folders map', () => {
  expect(parseConfig('{"folders":{"rpac":"work/plans"}}')).toEqual({ rpac: 'work/plans' })
})

test('parseConfig rejects what is not a folders map of strings', () => {
  expect(parseConfig('{nope')).toBeUndefined()
  expect(parseConfig('{"folders":[]}')).toBeUndefined()
  expect(parseConfig('{"folders":{"rpac":3}}')).toBeUndefined()
  expect(parseConfig('{"folders":{"rpac":""}}')).toBeUndefined()
})

test('rootsFor replaces the roots of the named workflow', () => {
  expect(rootsFor(rpac, { rpac: 'work/plans' })).toEqual(['work/plans'])
})

test('rootsFor keeps the defaults without a usable entry', () => {
  expect(rootsFor(rpac, {})).toEqual(rpac.roots)
  expect(rootsFor(rpac, { other: 'x' })).toEqual(rpac.roots)
  for (const bad of ['/abs', 'C:\\x', 'C:/x', 'a/../b']) expect(rootsFor(rpac, { rpac: bad })).toEqual(rpac.roots)
})
