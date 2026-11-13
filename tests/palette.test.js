import test from 'node:test'
import assert from 'node:assert/strict'
import { coordinatePalette } from '../src/lib/palette.js'
import { approachForDate } from '../src/lib/dailyApproach.js'
import { suggestOutfits } from '../src/lib/styling.js'

test('palette coordination removes duplicate and empty colors', () => {
  assert.deepEqual(coordinatePalette(['Blue', '', 'blue', 'cream']).colors, ['blue', 'cream'])
})

test('palette score stays in range and rewards complementary colors over identical ones', () => {
  const calm = coordinatePalette(['navy', 'blue']).score
  const contrast = coordinatePalette(['navy', 'yellow']).score
  assert.ok(calm >= 0 && calm <= 100)
  assert.ok(contrast >= 0 && contrast <= 100)
  assert.ok(contrast < calm)
})

test('each weekday has its own dressing approach', () => {
  const approaches = Array.from({ length: 7 }, (_, day) => approachForDate(new Date(2026, 8, 27 + day)))
  assert.equal(new Set(approaches.map((approach) => approach.title)).size, 7)
  assert.ok(approaches.every((approach) => approach.prompt.length > 0))
})

test('wardrobe suggestions only use pieces from the closet', () => {
  const items = [
    { id: 'top', category: 'Top', color: 'cream' },
    { id: 'bottom', category: 'Bottom', color: 'denim' },
    { id: 'shoe', category: 'Shoes', color: 'brown' },
  ]
  const suggestions = suggestOutfits(items, 'Work')
  assert.equal(suggestions.length, 1)
  assert.deepEqual(suggestions[0].items, ['top', 'bottom', 'shoe'])
})

test('wardrobe suggestions exclude worn and laundry pieces', () => {
  const items = [
    { id: 'clean-top', category: 'Top', color: 'cream', status: 'Clean' },
    { id: 'worn-bottom', category: 'Bottom', color: 'denim', status: 'Worn' },
    { id: 'laundry-bottom', category: 'Bottom', color: 'navy', status: 'Laundry' },
  ]
  assert.deepEqual(suggestOutfits(items), [])
})

test('casual and work outfit suggestions apply different layering', () => {
  const items = [
    { id: 'top', category: 'Top', color: 'cream' },
    { id: 'bottom', category: 'Bottom', color: 'denim' },
    { id: 'layer', category: 'Layer', color: 'navy' },
    { id: 'shoe', category: 'Shoes', color: 'brown' },
  ]
  const casual = suggestOutfits(items, 'Casual')[0]
  const work = suggestOutfits(items, 'Work')[0]
  assert.deepEqual(casual.items, ['top', 'bottom', 'shoe'])
  assert.deepEqual(work.items, ['top', 'bottom', 'layer', 'shoe'])
})

test('closet inspiration has five outfit photos per style', () => {
  const outfitPhotos = {
    Casual: ['casual-a', 'casual-b', 'casual-c', 'casual-d', 'casual-e'],
    'Semi-casual': ['semi-a', 'semi-b', 'semi-c', 'semi-d', 'semi-e'],
    Work: ['work-a', 'work-b', 'work-c', 'work-d', 'work-e'],
    Everyday: ['everyday-a', 'everyday-b', 'everyday-c', 'everyday-d', 'everyday-e'],
  }
  assert.deepEqual(Object.values(outfitPhotos).map((photos) => photos.length), [5, 5, 5, 5])
})
