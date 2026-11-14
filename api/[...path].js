import { createApp, createConfiguredStore } from '../server/index.js'

const { pool, store } = createConfiguredStore({ max: 1 })
const app = createApp(store)
let initialization = pool ? null : Promise.resolve()

export default async function handler(request, response) {
  if (!initialization) {
    initialization = store.initialize().catch((error) => {
      initialization = null
      throw error
    })
  }
  await initialization
  return app(request, response)
}
