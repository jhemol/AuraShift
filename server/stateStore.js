const emptyState = () => ({ items: [], looks: {}, settings: { weekStarts: 0, showLookNames: true, accent: 'forest' } })
const copy = (value) => value == null ? null : structuredClone(value)

export function createMemoryStore(initialState = null) {
  const states = new Map()
  if (initialState != null) states.set('test-user', copy(initialState))
  return {
    storage: 'memory',
    async check() { return true },
    async get(userId) { return copy(states.get(userId) ?? null) },
    async set(userId, value) { states.set(userId, copy(value)); return copy(value) },
  }
}

export function createPostgresStore(pool, legacyOwnerId = process.env.WARDROBE_LEGACY_OWNER_ID) {
  return {
    storage: 'postgres',
    async initialize() {
      await pool.query(`CREATE TABLE IF NOT EXISTS wardrobe_state (
        singleton_id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (singleton_id = 1),
        payload JSONB NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )`)
      await pool.query(`CREATE TABLE IF NOT EXISTS public.wardrobe_user_state (
        user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
        payload JSONB NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )`)
      await pool.query('ALTER TABLE public.wardrobe_user_state ENABLE ROW LEVEL SECURITY')
      await pool.query(`DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_policies
            WHERE schemaname = 'public'
              AND tablename = 'wardrobe_user_state'
              AND policyname = 'Users manage their own wardrobe'
          ) THEN
            CREATE POLICY "Users manage their own wardrobe"
              ON public.wardrobe_user_state
              FOR ALL
              USING (auth.uid() = user_id)
              WITH CHECK (auth.uid() = user_id);
          END IF;
        END
      $$`)
      await pool.query(`DO $$
        BEGIN
          IF to_regclass('public.wardrobe_state') IS NOT NULL THEN
            ALTER TABLE public.wardrobe_state ENABLE ROW LEVEL SECURITY;
          END IF;
        END
      $$`)
      if (legacyOwnerId && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(legacyOwnerId)) {
        const legacyTable = await pool.query("SELECT to_regclass('public.wardrobe_state') AS table_name")
        if (legacyTable.rows[0]?.table_name) {
          await pool.query(
            `INSERT INTO public.wardrobe_user_state (user_id, payload)
             SELECT $1::uuid, payload
             FROM public.wardrobe_state
             WHERE singleton_id = 1
             ON CONFLICT (user_id) DO NOTHING`,
            [legacyOwnerId],
          )
        }
      }
    },
    async check() {
      await pool.query('SELECT 1')
    },
    async get(userId) {
      const result = await pool.query('SELECT payload FROM public.wardrobe_user_state WHERE user_id = $1::uuid', [userId])
      return result.rows[0]?.payload ?? null
    },
    async set(userId, value) {
      const result = await pool.query(
        `INSERT INTO public.wardrobe_user_state (user_id, payload, updated_at)
         VALUES ($1::uuid, $2::jsonb, NOW())
         ON CONFLICT (user_id) DO UPDATE SET payload = EXCLUDED.payload, updated_at = NOW()
         RETURNING payload`,
        [userId, JSON.stringify(value)],
      )
      return result.rows[0].payload
    },
  }
}
