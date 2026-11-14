import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createApp, createDatabaseSslConfig } from '../server/index.js'
import { createMemoryStore } from '../server/stateStore.js'

async function withServer(run, store = createMemoryStore()) {
  const server = createApp(store).listen(0, '127.0.0.1')
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
    const saved = await fetch(`${baseUrl}/api/state`, { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify(state) })
    assert.equal(saved.status, 200)
    assert.deepEqual(await saved.json(), state)
    const loaded = await fetch(`${baseUrl}/api/state`)
    assert.deepEqual(await loaded.json(), state)
  })
})

test('wardrobe API rejects malformed state', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/state`, { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ items: 'not-an-array' }) })
    assert.equal(response.status, 400)
  })
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
