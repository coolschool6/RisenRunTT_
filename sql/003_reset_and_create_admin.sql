-- ⚠️ WARNING: This deletes ALL existing users, their profiles, and registrations.

-- STEP 1: Delete ALL existing data
DELETE FROM public.registrations;
DELETE FROM public.profiles;
DELETE FROM auth.users;

-- STEP 2: Go to Supabase Dashboard → Authentication → Users → Add User
--         Email: risenruntt@gmail.com
--         Password: Admin
--         ✅ Auto Confirm User = ON
--         Click "Create user"
--         (the profile will be auto-created by the trigger)

-- STEP 3: Then come back here and run this to set admin role:
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'risenruntt@gmail.com';

-- STEP 4: Verify
-- SELECT p.email, p.role, p.full_name FROM public.profiles p;
