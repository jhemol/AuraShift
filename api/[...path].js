import { createApp, createConfiguredStore } from '../server/index.js'

const { pool, store } = createConfiguredStore({ max: 1 })
const app = createApp(store)
let initialized = !pool

export default async function handler(request, response) {
  if (!initialized) {
    await store.initialize()
    initialized = true
  }
  return app(request, response)
}
