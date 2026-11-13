import test from 'node:test'
import assert from 'node:assert/strict'
import { groupOutfitCarouselItems, orderOutfitCarouselItems } from '../src/lib/outfitCarousel.js'

test('outfit carousel keeps pieces in top-to-accessories order and includes empty slots', () => {
  const items = [
    { id: 'shoes', name: 'Loafers', category: 'Shoes' },
    { id: 'layer', name: 'Cardigan', category: 'Layer' },
    { id: 'bottom', name: 'Trousers', category: 'Bottom' },
    { id: 'top', name: 'Shirt', category: 'Top' },
    { id: 'bag', name: 'Tote', category: 'Accessory' },
  ]

  assert.deepEqual(orderOutfitCarouselItems(items).map((item) => item.category), [
    'Top', 'Bottom', 'Dress', 'Layer', 'Shoes', 'Accessory',
  ])
  assert.deepEqual(orderOutfitCarouselItems(items).map((item) => item.id), [
    'top', 'bottom', 'placeholder-Dress', 'layer', 'shoes', 'bag',
  ])
})

test('outfit carousel keeps multiple pieces together in their category', () => {
  const ordered = orderOutfitCarouselItems([
    { id: 'first-top', category: 'Top' },
    { id: 'second-top', category: 'Top' },
    { id: 'accessory', category: 'Accessory' },
  ])

  assert.deepEqual(ordered.slice(0, 2).map((item) => item.id), ['first-top', 'second-top'])
  assert.deepEqual(ordered.map((item) => item.category), [
    'Top', 'Top', 'Bottom', 'Dress', 'Layer', 'Shoes', 'Accessory',
  ])
  assert.ok(ordered.every((item) => item.placeholder === true || item.placeholder === false))
})

test('outfit carousels keep each category independent with its own empty slot and rotation angles', () => {
  const groups = groupOutfitCarouselItems([
    { id: 'first-top', category: 'Top' },
    { id: 'second-top', category: 'Top' },
    { id: 'shoe', category: 'Shoes' },
  ])

  assert.deepEqual(groups.map((group) => group.key), [
    'Top', 'Bottom', 'Dress', 'Layer', 'Shoes', 'Accessory',
  ])
  assert.deepEqual(groups[0].items.map((item) => [item.id, item.angle]), [
    ['first-top', 0], ['second-top', 180],
  ])
  assert.deepEqual(groups[1].items.map((item) => item.id), ['placeholder-Bottom'])
  assert.deepEqual(groups[4].items.map((item) => item.id), ['shoe'])
  assert.ok(groups.flatMap((group) => group.items).every((item) => item.placeholder === true || item.placeholder === false))
})
