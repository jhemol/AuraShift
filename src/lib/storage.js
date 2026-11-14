import { supabase } from './supabase.js'

const storageKey = 'thread-wardrobe-v1'

async function currentUserSession() {
  if (!supabase) return null
  const { data } = await supabase.auth.getSession()
  return data.session
}

export async function loadWardrobe() {
  const session = await currentUserSession()
  if (!session) return null
  const userStorageKey = `${storageKey}:${session.user.id}`
  try {
    const response = await fetch('/api/state', {
      headers: { authorization: `Bearer ${session.access_token}` },
    })
    if (response.ok) {
      const data = await response.json()
      if (data && Array.isArray(data.items)) {
        localStorage.setItem(userStorageKey, JSON.stringify(data))
        return data
      }
    }
  } catch {
    // The browser app can run without the API server.
  }

  try {
    const stored = localStorage.getItem(userStorageKey)
    return stored ? JSON.parse(stored) : null
  } catch {
    return null
  }
}

export async function saveWardrobe(state) {
  const session = await currentUserSession()
  if (!session) return
  const data = JSON.parse(JSON.stringify(state))
  const userStorageKey = `${storageKey}:${session.user.id}`
  try {
    localStorage.setItem(userStorageKey, JSON.stringify(data))
  } catch {
    // Quota or browser storage restrictions should not interrupt outfit editing.
  }

  try {
    await fetch('/api/state', {
      method: 'PUT',
      headers: {
        authorization: `Bearer ${session.access_token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(data),
    })
  } catch {
    // The PostgreSQL API is optional during local-only use.
  }
}