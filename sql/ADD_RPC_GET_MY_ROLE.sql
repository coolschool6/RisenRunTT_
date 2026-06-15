-- Run in Supabase SQL Editor.
-- Creates an RPC function that bypasses RLS to get the current user's role.

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Verify it works (should return 'admin' if you've set it)
-- SELECT public.get_my_role();
