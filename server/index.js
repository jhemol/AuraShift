import 'dotenv/config'
import express from 'express'
import { readFileSync } from 'node:fs'
import { Pool } from 'pg'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import { createClient } from '@supabase/supabase-js'
import { createMemoryStore, createPostgresStore } from './stateStore.js'

export function createApp(store, { authenticate = createAuthMiddleware() } = {}) {
  const app = express()
  app.use(express.json({ limit: '8mb' }))
  app.get('/api/health', async (_request, response) => {
    try {
      await store.check?.()
      response.json({ ok: true, storage: store.storage ?? 'unknown' })
    } catch (error) {
      console.error('Storage health check failed:', error.message)
      response.status(503).json({ ok: false, error: 'Storage unavailable.' })
    }
  })
  app.use('/api/state', authenticate)
  app.get('/api/state', async (_request, response) => {
    response.json(await store.get(response.locals.userId))
  })
  app.put('/api/state', async (request, response) => {
    const value = request.body
    if (!value || !Array.isArray(value.items) || typeof value.looks !== 'object' || value.looks === null || typeof value.settings !== 'object' || value.settings === null) {
      return response.status(400).json({ error: 'State must include items, looks, and settings.' })
    }
    if (value.items.length > 500 || Object.keys(value.looks).length > 500) {
      return response.status(413).json({ error: 'Wardrobe state exceeds the supported size.' })
    }
    response.json(await store.set(response.locals.userId, value))
  })
  return app
}

export function createAuthMiddleware({
  verifyToken = verifySupabaseToken,
  isConfigured = () => Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_PUBLISHABLE_KEY),
} = {}) {
  return async (request, response, next) => {
    if (!isConfigured()) {
      return response.status(503).json({ error: 'Authentication is not configured.' })
    }

    const authorization = request.get('authorization') ?? ''
    const match = /^Bearer\s+(.+)$/i.exec(authorization)
    if (!match) return response.status(401).json({ error: 'Sign in is required.' })

    try {
      const claims = await verifyToken(match[1])
      if (typeof claims.sub !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(claims.sub)) {
        return response.status(401).json({ error: 'Invalid access token.' })
      }
      response.locals.userId = claims.sub
      return next()
    } catch {
      return response.status(401).json({ error: 'Invalid or expired access token.' })
    }
  }
}

let tokenVerifier
async function verifySupabaseToken(token) {
  tokenVerifier ??= createClient(process.env.SUPABASE_URL, process.env.SUPABASE_PUBLISHABLE_KEY, {
    auth: { autoRefreshToken: false, detectSessionInUrl: false, persistSession: false },
  })
  const { data, error } = await tokenVerifier.auth.getUser(token)
  if (error || !data.user) throw error ?? new Error('Supabase did not return an authenticated user.')
  return { sub: data.user.id }
}

export function createConfiguredStore({ max = 5 } = {}) {
  const pool = process.env.DATABASE_URL
    ? new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: createDatabaseSslConfig(),
      max,
      connectionTimeoutMillis: 10_000,
      idleTimeoutMillis: 30_000,
    })
    : null
  return { pool, store: pool ? createPostgresStore(pool) : createMemoryStore() }
}

export function createDatabaseSslConfig({ sslMode = process.env.PGSSLMODE, sslRootCert = process.env.PGSSLROOTCERT } = {}) {
  if (sslMode !== 'require') return undefined

  const ca = sslRootCert?.includes('-----BEGIN CERTIFICATE-----')
    ? sslRootCert
    : sslRootCert
      ? readFileSync(resolve(sslRootCert), 'utf8')
      : undefined

  return { rejectUnauthorized: true, ...(ca ? { ca } : {}) }
}

async function start() {
  const { pool, store } = createConfiguredStore()
  if (pool) await store.initialize()
  const port = Number(process.env.API_PORT || 5174)
  const server = createApp(store).listen(port, () => {
    console.log(`Wardrobe API listening on http://localhost:${port}${pool ? ' (PostgreSQL)' : ' (memory store)'}`)
  })
  const shutdown = async () => {
    server.close()
    if (pool) await pool.end()
  }
  process.on('SIGINT', shutdown)
  process.on('SIGTERM', shutdown)
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  start().catch((error) => { console.error(error); process.exitCode = 1 })
}
