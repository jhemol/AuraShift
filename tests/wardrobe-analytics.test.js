import assert from 'node:assert/strict'
import test from 'node:test'
import { buildWardrobeReportCsv, getWardrobeAnalytics } from '../src/lib/wardrobeAnalytics.js'

const items = [
  { id: 'top', name: 'Linen "favorite"', category: 'Top', color: 'cream', season: 'Summer', status: 'Clean', tags: ['breathable'] },
  { id: 'dress', name: 'Sunday dress', category: 'Dress', color: 'red', season: 'All season', status: 'Worn', tags: [] },
  { id: 'shoe', name: 'Loafers', category: 'Shoes', color: 'brown', season: 'All season', status: 'Laundry', tags: [] },
]

test('wardrobe analytics count pieces by known category and care state', () => {
  assert.deepEqual(getWardrobeAnalytics(items, { today: {}, tomorrow: {} }), {
    totalItems: 3,
    plannedLooks: 2,
    statusCounts: { Clean: 1, Worn: 1, Laundry: 1 },
    categoryCounts: { Top: 1, Bottom: 0, Dress: 1, Layer: 0, Shoes: 1, Accessory: 0 },
  })
})

test('CSV wardrobe report includes analytics, weather, item details, and escaped cells', () => {
  const report = buildWardrobeReportCsv({
    items,
    looks: { today: {} },
    weather: { city: 'Manila', description: 'Rain', temperature: 29, precipitation: 1.2 },
    generatedAt: new Date('2026-11-13T00:00:00.000Z'),
  })
  assert.match(report, /"Status","Laundry","1"/)
  assert.match(report, /"Weather","City","Manila"/)
  assert.match(report, /"Item","Linen ""favorite""","Clean"/)
  assert.match(report, /"Summary","Planned looks","1"/)
})
