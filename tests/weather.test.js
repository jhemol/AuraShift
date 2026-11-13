import test from 'node:test'
import assert from 'node:assert/strict'
import { getWeather } from '../src/lib/weather.js'

test('weather lookup resolves a city and returns current conditions', async (context) => {
  const originalFetch = globalThis.fetch
  const calls = []
  globalThis.fetch = async (url) => {
    calls.push(String(url))
    return calls.length === 1
      ? Response.json({ results: [{ name: 'Manila', latitude: 14.6, longitude: 120.9 }] })
      : Response.json({ current: { temperature_2m: 29, precipitation: 1.2, weather_code: 61 } })
  }
  context.after(() => { globalThis.fetch = originalFetch })

  assert.deepEqual(await getWeather('Manila'), {
    city: 'Manila',
    temperature: 29,
    precipitation: 1.2,
    description: 'Rain',
  })
  assert.equal(calls.length, 2)
  assert.match(calls[1], /latitude=14.6/)
})

test('weather lookup reports an unknown city clearly', async (context) => {
  const originalFetch = globalThis.fetch
  globalThis.fetch = async () => Response.json({ results: [] })
  context.after(() => { globalThis.fetch = originalFetch })

  await assert.rejects(getWeather('No such place'), /No matching city was found/)
})
