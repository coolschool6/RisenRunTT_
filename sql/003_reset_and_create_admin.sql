-- ⚠️ WARNING: This deletes ALL existing users, their profiles, and registrations.
-- Run in Supabase SQL Editor.

-- 1) Delete registrations (depends on auth.users)
DELETE FROM public.registrations;

-- 2) Delete profiles (depends on auth.users)
DELETE FROM public.profiles;

-- 3) Delete all auth users (cascading removal)
DELETE FROM auth.users;

-- 4) Create a single admin user
SELECT auth.admin_create_user(
  email => 'risenruntt@gmail.com',
  password => 'Admin',
  email_confirm => true,
  user_metadata => jsonb_build_object('full_name', 'Admin')
);

-- 5) Backfill profile (in case trigger didn't fire)
INSERT INTO public.profiles (id, full_name, email)
SELECT id, COALESCE(raw_user_meta_data->>'full_name', email), email
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 6) Set role to admin
UPDATE public.profiles SET role = 'admin' WHERE email = 'risenruntt@gmail.com';

-- 7) Verify
SELECT p.email, p.role, p.full_name FROM public.profiles p WHERE p.email = 'risenruntt@gmail.com';
