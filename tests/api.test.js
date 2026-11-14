import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createApp, createAuthMiddleware, createDatabaseSslConfig } from '../server/index.js'
import { createMemoryStore } from '../server/stateStore.js'

const userId = 'c0a80123-4567-489a-8abc-123456789abc'
const authenticated = createAuthMiddleware({
  isConfigured: () => true,
  verifyToken: async (token) => {
    if (token !== 'valid-test-token') throw new Error('Invalid test token')
    return { sub: userId }
  },
})

async function withServer(run, store = createMemoryStore(), authenticate = authenticated) {
  const server = createApp(store, { authenticate }).listen(0, '127.0.0.1')
  await new Promise((resolve) => server.once('listening', resolve))
  const address = server.address()
  try {
    await run(`http://127.0.0.1:${address.port}`)
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()))
  }
}

test('wardrobe API saves and reads state', async () => {
  await withServer(async (baseUrl) => {
    const state = { items: [{ id: 'shirt-1', name: 'Blue shirt' }], looks: { '2026-09-30': { title: 'Blue day', items: ['shirt-1'] } }, settings: { weekStarts: 1 } }
    const saved = await fetch(`${baseUrl}/api/state`, { method: 'PUT', headers: { authorization: 'Bearer valid-test-token', 'content-type': 'application/json' }, body: JSON.stringify(state) })
    assert.equal(saved.status, 200)
    assert.deepEqual(await saved.json(), state)
    const loaded = await fetch(`${baseUrl}/api/state`, { headers: { authorization: 'Bearer valid-test-token' } })
    assert.deepEqual(await loaded.json(), state)
  })
})

test('wardrobe API rejects malformed state', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/state`, { method: 'PUT', headers: { authorization: 'Bearer valid-test-token', 'content-type': 'application/json' }, body: JSON.stringify({ items: 'not-an-array' }) })
    assert.equal(response.status, 400)
  })
})

test('wardrobe API requires a verified sign-in', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/state`)
    assert.equal(response.status, 401)
    assert.deepEqual(await response.json(), { error: 'Sign in is required.' })
  })
})

test('wardrobe API fails closed when Supabase auth is not configured', async () => {
  const authenticate = createAuthMiddleware({ isConfigured: () => false })
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/state`, { headers: { authorization: 'Bearer valid-test-token' } })
    assert.equal(response.status, 503)
    assert.deepEqual(await response.json(), { error: 'Authentication is not configured.' })
  }, createMemoryStore(), authenticate)
})

test('wardrobe API rejects invalid access tokens', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/state`, { headers: { authorization: 'Bearer invalid-token' } })
    assert.equal(response.status, 401)
    assert.deepEqual(await response.json(), { error: 'Invalid or expired access token.' })
  })
})

test('wardrobe API isolates each authenticated user', async () => {
  const secondUserId = 'd0a80123-4567-489a-8abc-123456789abc'
  const authenticate = createAuthMiddleware({
    isConfigured: () => true,
    verifyToken: async (token) => {
      if (token === 'user-one') return { sub: userId }
      if (token === 'user-two') return { sub: secondUserId }
      throw new Error('Invalid test token')
    },
  })
  await withServer(async (baseUrl) => {
    const firstState = { items: [{ id: 'private-item' }], looks: {}, settings: {} }
    await fetch(`${baseUrl}/api/state`, { method: 'PUT', headers: { authorization: 'Bearer user-one', 'content-type': 'application/json' }, body: JSON.stringify(firstState) })
    const firstUserRead = await fetch(`${baseUrl}/api/state`, { headers: { authorization: 'Bearer user-one' } })
    const secondUserRead = await fetch(`${baseUrl}/api/state`, { headers: { authorization: 'Bearer user-two' } })
    assert.deepEqual(await firstUserRead.json(), firstState)
    assert.equal(await secondUserRead.json(), null)
  }, createMemoryStore(), authenticate)
})

test('health endpoint identifies the active storage', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/health`)
    assert.equal(response.status, 200)
    assert.deepEqual(await response.json(), { ok: true, storage: 'memory' })
  })
})

test('health endpoint reports unavailable database storage', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/health`)
    assert.equal(response.status, 503)
    assert.deepEqual(await response.json(), { ok: false, error: 'Storage unavailable.' })
  }, {
    storage: 'postgres',
    async check() { throw new Error('connection refused') },
  })
})

test('database SSL verifies certificates and accepts a trusted CA file or PEM', () => {
  const certificate = '-----BEGIN CERTIFICATE-----\ntrusted-ca\n-----END CERTIFICATE-----'
  const directory = mkdtempSync(join(tmpdir(), 'wardrobe-ca-'))
  const certificatePath = join(directory, 'ca.crt')
  writeFileSync(certificatePath, certificate)

  try {
    assert.equal(createDatabaseSslConfig({ sslMode: 'disable' }), undefined)
    assert.deepEqual(createDatabaseSslConfig({ sslMode: 'require', sslRootCert: '' }), { rejectUnauthorized: true })
    assert.deepEqual(createDatabaseSslConfig({ sslMode: 'require', sslRootCert: certificate }), {
      rejectUnauthorized: true,
      ca: certificate,
    })
    assert.deepEqual(createDatabaseSslConfig({ sslMode: 'require', sslRootCert: certificatePath }), {
      rejectUnauthorized: true,
      ca: certificate,
    })
  } finally {
    rmSync(directory, { recursive: true, force: true })
  }
})
