CREATE TABLE IF NOT EXISTS public.wardrobe_state (
  singleton_id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (singleton_id = 1),
  payload JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.wardrobe_state ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.wardrobe_user_state (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  payload JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.wardrobe_user_state ENABLE ROW LEVEL SECURITY;

DO $$
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
$$;
