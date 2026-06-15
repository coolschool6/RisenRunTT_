-- Run ALL of this in Supabase SQL Editor.
-- Fixes admin access regardless of email case, fixes events 500 errors.

-- 1) Show current state
SELECT '--- AUTH USERS ---' as info;
SELECT id, email FROM auth.users;

SELECT '--- PROFILES BEFORE ---' as info;
SELECT id, email, full_name, role FROM public.profiles;

-- 2) Create/update profile with case-insensitive email match
INSERT INTO public.profiles (id, full_name, email, role)
SELECT id, 'Admin', email, 'admin'
FROM auth.users
WHERE LOWER(email) = 'risenruntt@gmail.com'
ON CONFLICT (id) DO UPDATE SET full_name = 'Admin', role = 'admin';

-- 3) If no match with the email, try finding any user and make them admin
DO $$
DECLARE
  user_count integer;
BEGIN
  SELECT COUNT(*) INTO user_count FROM public.profiles WHERE role = 'admin';
  IF user_count = 0 THEN
    -- No admin found — make the first user in auth.users the admin
    INSERT INTO public.profiles (id, full_name, email, role)
    SELECT id, 'Admin', email, 'admin'
    FROM auth.users
    WHERE id NOT IN (SELECT id FROM public.profiles)
    LIMIT 1
    ON CONFLICT (id) DO UPDATE SET full_name = 'Admin', role = 'admin';
    
    -- If no new user to insert, update the first existing profile
    IF NOT FOUND THEN
      UPDATE public.profiles SET full_name = 'Admin', role = 'admin'
      WHERE id = (SELECT id FROM public.profiles ORDER BY created_at LIMIT 1);
    END IF;
  END IF;
END $$;

-- 4) Fix events policies — drop admin policy that may cause 500 errors
DROP POLICY IF EXISTS "Admins can manage events" ON public.events;

-- Recreate with a simpler check that won't error
CREATE POLICY "Admins can manage events" ON public.events
  FOR ALL USING (
    auth.uid() IN (SELECT id FROM public.profiles WHERE role = 'admin')
  );

-- 5) Show result
SELECT '--- PROFILES AFTER ---' as info;
SELECT id, email, full_name, role FROM public.profiles;

SELECT '--- ADMIN CHECK ---' as info;
SELECT public.get_my_role();

-- 6) Refresh schema cache
NOTIFY pgrst, 'reload schema';
