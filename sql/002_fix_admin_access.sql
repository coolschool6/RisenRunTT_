-- Run this in Supabase SQL Editor AFTER 001_add_proof_status.sql
-- Fixes: admin account blocked, duplicate policies, missing profile

-- 1) Backfill missing profiles for users who signed up before trigger existed
INSERT INTO public.profiles (id, full_name, email)
SELECT id, COALESCE(raw_user_meta_data->>'full_name', email), email
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 2) Set admin role (replace with your actual email)
UPDATE public.profiles SET role = 'admin' WHERE email = 'risenruntt@gmail.com';

-- 3) Recreate events RLS policies (in case they were dropped)
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view events" ON public.events;
CREATE POLICY "Public can view events" ON public.events
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage events" ON public.events;
CREATE POLICY "Admins can manage events" ON public.events
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 3b) Verify events still exist
SELECT id, title, start_date FROM public.events ORDER BY created_at DESC;

-- 4) Refresh PostgREST schema cache again
NOTIFY pgrst, 'reload schema';

-- 5) Verify admin status
SELECT p.id, p.email, p.role, p.created_at FROM public.profiles p WHERE p.role = 'admin';
