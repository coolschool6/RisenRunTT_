-- ============================================================
-- DIAGNOSE_ADMIN.sql — Run this in SQL Editor
-- ============================================================

-- 1. Does the profile exist with correct role?
SELECT id, email, full_name, role FROM public.profiles WHERE email = 'risenruntt@gmail.com';

-- 2. Does the RPC function exist and return the right value?
SELECT public.get_my_role() as rpc_returned_role;

-- 3. Is the trigger active?
SELECT tgname FROM pg_trigger WHERE tgname = 'on_auth_user_created';

-- 4. Does the RLS policy on profiles exist?
SELECT policyname FROM pg_policies WHERE tablename = 'profiles';

-- 5. Can the RPC actually query the row (auth.uid test)?
-- This will show NULL if auth.uid() doesn't match any profile row
SELECT auth.uid() as my_uid;
SELECT * FROM public.profiles WHERE id = auth.uid();
