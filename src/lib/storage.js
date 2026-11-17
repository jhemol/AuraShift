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

export async function loadSharedWardrobe() {
  try {
    const session = await currentUserSession()
    if (!session) return { data: null, error: 'Sign in to sync your wardrobe with mobile.' }
    const response = await fetch('/api/state', {
      headers: { authorization: `Bearer ${session.access_token}` },
    })
    if (!response.ok) return { data: null, error: `The wardrobe API could not load your data (HTTP ${response.status}).` }
    const data = await response.json()
    if (!data || !Array.isArray(data.items)) return { data: null, error: 'The wardrobe API returned an invalid state document.' }
    try {
      localStorage.setItem(`${storageKey}:${session.user.id}`, JSON.stringify(data))
    } catch (error) {
      return { data, error: `Loaded shared data, but could not cache it locally: ${error.message}` }
    }
    return { data, error: null }
  } catch (error) {
    return { data: null, error: `Could not sync with the web app: ${error.message}` }
  }
}

export async function saveWardrobe(state) {
  const session = await currentUserSession()
  if (!session) return { synced: false, localSaved: false, error: 'Sign in to sync your wardrobe.' }
  const data = JSON.parse(JSON.stringify(state))
  const userStorageKey = `${storageKey}:${session.user.id}`
  let localSaved = false
  let localSaveError
  try {
    localStorage.setItem(userStorageKey, JSON.stringify(data))
    localSaved = true
  } catch (error) {
    localSaveError = error
  }

  try {
    const response = await fetch('/api/state', {
      method: 'PUT',
      headers: {
        authorization: `Bearer ${session.access_token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(data),
    })
    if (!response.ok) {
      const error = `The wardrobe API could not save your data (HTTP ${response.status}).`
      return { synced: false, localSaved, error: localSaveError ? `${error} Local cache also failed: ${localSaveError.message}` : error }
    }
    return { synced: true, localSaved, error: null }
  } catch (error) {
    const syncError = `Could not sync your wardrobe: ${error.message}`
    return { synced: false, localSaved, error: localSaveError ? `${syncError} Local cache also failed: ${localSaveError.message}` : syncError }
  }
}