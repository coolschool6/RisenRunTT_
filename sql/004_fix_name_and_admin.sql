-- Fix name display and ensure RLS policies exist
-- Run this in Supabase SQL Editor

-- 1) Fix the display name
UPDATE public.profiles SET full_name = 'Admin' WHERE email = 'risenruntt@gmail.com';

-- 2) Ensure profiles RLS policies exist
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own profile" ON public.profiles;
CREATE POLICY "Users read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- 3) Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- 4) Verify
SELECT email, full_name, role FROM public.profiles;
