import assert from 'node:assert/strict'
import test from 'node:test'
import { nextGarmentStatus, normalizeGarmentStatus } from '../src/lib/garmentCare.js'

test('garment care follows the clean, worn, laundry cycle', () => {
  assert.equal(nextGarmentStatus('Clean'), 'Worn')
  assert.equal(nextGarmentStatus('Worn'), 'Laundry')
  assert.equal(nextGarmentStatus('Laundry'), 'Clean')
  assert.equal(nextGarmentStatus('Unknown'), undefined)
})

test('legacy washing status is migrated to laundry', () => {
  assert.equal(normalizeGarmentStatus('Washing'), 'Laundry')
  assert.equal(normalizeGarmentStatus('Clean'), 'Clean')
  assert.equal(normalizeGarmentStatus('Unknown'), 'Clean')
})
