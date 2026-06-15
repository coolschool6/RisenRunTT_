-- Fix storage RLS policies to use SECURITY DEFINER RPC (bypasses profiles RLS)
-- Run this in Supabase SQL Editor

-- 1) Ensure the RPC function exists
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- 2) Recreate storage policies using the RPC (bypasses RLS on profiles)
DROP POLICY IF EXISTS "Admins manage event-banners" ON storage.objects;
CREATE POLICY "Admins manage event-banners" ON storage.objects
  FOR ALL USING (
    bucket_id = 'event-banners' AND
    public.get_my_role() = 'admin'
  );

DROP POLICY IF EXISTS "Public read event-banners" ON storage.objects;
CREATE POLICY "Public read event-banners" ON storage.objects
  FOR SELECT USING (bucket_id = 'event-banners');

DROP POLICY IF EXISTS "Users upload proofs" ON storage.objects;
CREATE POLICY "Users upload proofs" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'proofs' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users read own proofs" ON storage.objects;
CREATE POLICY "Users read own proofs" ON storage.objects
  FOR SELECT USING (bucket_id = 'proofs' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins read all proofs" ON storage.objects;
CREATE POLICY "Admins read all proofs" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'proofs' AND public.get_my_role() = 'admin'
  );

DROP POLICY IF EXISTS "Users upload screenshots" ON storage.objects;
CREATE POLICY "Users upload screenshots" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'screenshots' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users read own screenshots" ON storage.objects;
CREATE POLICY "Users read own screenshots" ON storage.objects
  FOR SELECT USING (bucket_id = 'screenshots' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins read all screenshots" ON storage.objects;
CREATE POLICY "Admins read all screenshots" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'screenshots' AND public.get_my_role() = 'admin'
  );

-- 3) Fix table policies too — use RPC to bypass profiles RLS

DROP POLICY IF EXISTS "Admins can manage events" ON public.events;
CREATE POLICY "Admins can manage events" ON public.events
  FOR ALL USING (public.get_my_role() = 'admin');

DROP POLICY IF EXISTS "Admin all registrations" ON public.registrations;
CREATE POLICY "Admin all registrations" ON public.registrations
  FOR ALL USING (public.get_my_role() = 'admin');

DROP POLICY IF EXISTS "Admin all profiles" ON public.profiles;
CREATE POLICY "Admin all profiles" ON public.profiles
  FOR ALL USING (public.get_my_role() = 'admin');

-- 4) Refresh schema cache
NOTIFY pgrst, 'reload schema';
