import assert from 'node:assert/strict'
import test from 'node:test'
import { getWeatherBasedSuggestions } from '../src/lib/weatherSuggestions.js'

const items = [
  { id: 'rain-shell', name: 'Rain shell', category: 'Layer', status: 'Clean', tags: ['waterproof'] },
  { id: 'linen-top', name: 'Linen top', category: 'Top', status: 'Clean', tags: ['linen', 'breathable'] },
  { id: 'wool-coat', name: 'Wool coat', category: 'Layer', status: 'Clean', tags: ['wool'] },
  { id: 'worn-shell', name: 'Worn shell', category: 'Layer', status: 'Worn', tags: ['waterproof'] },
  { id: 'laundry-shoes', name: 'Laundry shoes', category: 'Shoes', status: 'Laundry', tags: ['waterproof'] },
]

test('rain suggestions prioritize clean tagged rainwear and never recommend unavailable items', () => {
  const result = getWeatherBasedSuggestions(items, { city: 'Manila', temperature: 29, precipitation: 2, description: 'Rain' })
  assert.equal(result.title, 'Rain-ready picks')
  assert.equal(result.matched, true)
  assert.equal(result.items[0].id, 'rain-shell')
  assert.ok(result.items.every((item) => item.status === 'Clean'))
})

test('hot and cold weather suggestions match related fabric tags', () => {
  const hot = getWeatherBasedSuggestions(items, { city: 'Manila', temperature: 30, precipitation: 0, description: 'Clear skies' })
  const cold = getWeatherBasedSuggestions(items, { city: 'Baguio', temperature: 10, precipitation: 0, description: 'Cloudy' })
  assert.equal(hot.title, 'Light and breathable')
  assert.equal(hot.items[0].id, 'linen-top')
  assert.equal(cold.title, 'Warm layers')
  assert.equal(cold.items[0].id, 'wool-coat')
})

test('weather suggestions show clean fallback pieces when there are no tagged matches', () => {
  const result = getWeatherBasedSuggestions([{ id: 'top', category: 'Top', status: 'Clean' }], {
    city: 'Manila', temperature: 30, precipitation: 0, description: 'Clear skies',
  })
  assert.equal(result.matched, false)
  assert.equal(result.items[0].id, 'top')
  assert.match(result.detail, /tag weather-ready pieces/)
})
