import test from 'node:test'
import assert from 'node:assert/strict'
import { sortClosetItems } from '../src/lib/closet.js'

const items = [
  { id: 'one', name: 'Linen Shirt', category: 'Top', color: 'Cream', status: 'Clean' },
  { id: 'two', name: 'Canvas Shoes', category: 'Shoes', color: 'White', status: 'Worn' },
  { id: 'three', name: 'Denim Jeans', category: 'Bottom', color: 'Blue', status: 'Washing' },
]

test('closet sorting supports name, category, color, and status', () => {
  assert.deepEqual(sortClosetItems(items, 'name').map((item) => item.id), ['two', 'three', 'one'])
  assert.deepEqual(sortClosetItems(items, 'category').map((item) => item.id), ['three', 'two', 'one'])
  assert.deepEqual(sortClosetItems(items, 'color').map((item) => item.id), ['three', 'one', 'two'])
  assert.deepEqual(sortClosetItems(items, 'status').map((item) => item.id), ['one', 'three', 'two'])
})

test('recent and unknown sort options preserve newest-first order without mutating input', () => {
  assert.deepEqual(sortClosetItems(items, 'recent'), items)
  assert.deepEqual(sortClosetItems(items, 'unknown'), items)
  assert.deepEqual(items.map((item) => item.id), ['one', 'two', 'three'])
})
