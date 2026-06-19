-- ============================================================
-- FIX_ADMIN_PROFILE.sql
-- Ensures risenruntt@gmail.com has an admin profile
-- ============================================================
-- Run this in Supabase Dashboard → SQL Editor

DO $$
DECLARE
  user_id uuid;
BEGIN
  -- Find the user in auth.users
  SELECT id INTO user_id FROM auth.users WHERE email = 'risenruntt@gmail.com';
  
  IF user_id IS NULL THEN
    RAISE EXCEPTION 'User risenruntt@gmail.com not found in auth.users. Create them first in Authentication → Users (auto-confirm ON).';
  END IF;

  -- Upsert profile: insert if missing, update if exists
  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (user_id, 'Admin', 'risenruntt@gmail.com', 'admin')
  ON CONFLICT (id) DO UPDATE SET
    full_name = 'Admin',
    role = 'admin';

  RAISE NOTICE 'Admin profile ready for risenruntt@gmail.com (id: %)', user_id;
END $$;

-- Verify
SELECT id, email, full_name, role FROM public.profiles WHERE email = 'risenruntt@gmail.com';

-- Test the RPC
SELECT public.get_my_role() as current_user_role;
