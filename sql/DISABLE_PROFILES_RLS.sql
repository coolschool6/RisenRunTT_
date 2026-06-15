-- Disable RLS on profiles (causes infinite recursion with get_my_role())
-- All other policies use get_my_role() (SECURITY DEFINER) which bypasses RLS anyway.

ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Drop self-referential policies on profiles (no longer needed)
DROP POLICY IF EXISTS "Users read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admin all profiles" ON public.profiles;

NOTIFY pgrst, 'reload schema';
