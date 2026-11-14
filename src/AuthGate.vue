<script setup>
import { onMounted, onUnmounted, ref } from 'vue'
import App from './App.vue'
import { supabase } from './lib/supabase.js'

const session = ref(null)
const loading = ref(true)
const busy = ref(false)
const creatingAccount = ref(false)
const email = ref('')
const password = ref('')
const error = ref('')
const message = ref('')
let subscription

onMounted(async () => {
  if (!supabase) {
    loading.value = false
    return
  }
  const { data, error: sessionError } = await supabase.auth.getSession()
  if (sessionError) error.value = sessionError.message
  session.value = data?.session ?? null
  loading.value = false
  const result = supabase.auth.onAuthStateChange((_event, nextSession) => {
    session.value = nextSession
  })
  subscription = result.data.subscription
})

onUnmounted(() => subscription?.unsubscribe())

async function submit() {
  if (!supabase) return
  busy.value = true
  error.value = ''
  message.value = ''
  try {
    const result = creatingAccount.value
      ? await supabase.auth.signUp({ email: email.value.trim(), password: password.value })
      : await supabase.auth.signInWithPassword({ email: email.value.trim(), password: password.value })
    if (result.error) throw result.error
    if (creatingAccount.value && !result.data.session) {
      message.value = 'Check your email to confirm your account, then sign in.'
    }
  } catch (caught) {
    error.value = caught.message || 'Sign-in failed. Please try again.'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div v-if="loading" class="auth-loading" role="status">Loading your secure wardrobe…</div>
  <component :is="App" v-else-if="session" />
  <main v-else class="auth-page">
    <section class="auth-card">
      <a class="auth-brand" href="/" aria-label="AuraShift home">Aura<span>Shift</span></a>
      <p class="auth-eyebrow">YOUR PRIVATE WARDROBE</p>
      <h1>{{ creatingAccount ? 'Create your account' : 'Welcome back' }}</h1>
      <p class="auth-description">Sign in to sync your closet and outfit plans across web and mobile.</p>
      <p v-if="!supabase" class="auth-error" role="alert">Supabase sign-in is not configured. Add VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY to your local environment and deployment settings.</p>
      <form v-else @submit.prevent="submit">
        <label>Email<input v-model="email" type="email" autocomplete="email" required /></label>
        <label>Password<input v-model="password" :autocomplete="creatingAccount ? 'new-password' : 'current-password'" type="password" minlength="8" required /></label>
        <p v-if="error" class="auth-error" role="alert">{{ error }}</p>
        <p v-if="message" class="auth-message" role="status">{{ message }}</p>
        <button class="auth-submit" type="submit" :disabled="busy">{{ busy ? 'Please wait…' : creatingAccount ? 'Create account' : 'Sign in' }}</button>
      </form>
      <button v-if="supabase" class="auth-switch" type="button" @click="creatingAccount = !creatingAccount; error = ''; message = ''">
        {{ creatingAccount ? 'Already have an account? Sign in' : 'New here? Create an account' }}
      </button>
    </section>
  </main>
</template>

<style>
.auth-loading,
.auth-page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background: #f4f5f0;
  color: #28362e;
  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
}

.auth-card {
  width: min(100%, 430px);
  padding: 38px;
  border: 1px solid #e1e6de;
  border-radius: 24px;
  background: #fff;
  box-shadow: 0 24px 70px #28362e12;
}

.auth-brand {
  color: #28362e;
  font-size: 24px;
  font-weight: 800;
  letter-spacing: -.8px;
  text-decoration: none;
}

.auth-brand span { color: #6b826b; }
.auth-eyebrow { margin: 34px 0 8px; color: #72816f; font-size: 10px; font-weight: 800; letter-spacing: 1.7px; }
.auth-card h1 { margin: 0; font-size: 29px; letter-spacing: -1px; }
.auth-description { margin: 10px 0 26px; color: #747d74; font-size: 14px; line-height: 1.6; }
.auth-card form { display: grid; gap: 16px; }
.auth-card label { display: grid; gap: 7px; color: #38463b; font-size: 12px; font-weight: 700; }
.auth-card input { width: 100%; padding: 12px 13px; border: 1px solid #dce3da; border-radius: 11px; color: #28362e; font: inherit; outline-color: #708b71; }
.auth-submit { min-height: 46px; border: 0; border-radius: 12px; background: #58735d; color: #fff; font: inherit; font-weight: 700; cursor: pointer; }
.auth-submit:disabled { opacity: .65; cursor: wait; }
.auth-switch { width: 100%; margin-top: 18px; border: 0; background: none; color: #58735d; font: inherit; font-size: 13px; font-weight: 700; cursor: pointer; }
.auth-error, .auth-message { padding: 11px 12px; border-radius: 10px; font-size: 12px; line-height: 1.5; }
.auth-error { background: #fff0ef; color: #a53d35; }
.auth-message { background: #edf5ec; color: #426c46; }

@media (max-width: 480px) {
  .auth-card { padding: 28px 22px; }
}
</style>
