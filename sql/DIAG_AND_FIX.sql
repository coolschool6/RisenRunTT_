-- Run this in Supabase SQL Editor.
-- Checks what tables/columns exist and creates the RPC function.

-- 1) Diagnostic
SELECT table_name, table_schema FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- 2) Create the RPC function (needed by main.js admin check)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- 3) If events table doesn't exist, this will fail harmlessly
--    If it exists, we ensure RLS policies exist
CREATE TABLE IF NOT EXISTS public.events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    title TEXT NOT NULL,
    organizer_name TEXT NOT NULL,
    location TEXT NOT NULL,
    category TEXT NOT NULL,
    event_type TEXT NOT NULL DEFAULT 'Virtual',
    price NUMERIC(10, 2) DEFAULT 0.00,
    tags TEXT[],
    country TEXT NOT NULL,
    banner_url TEXT,
    description TEXT NOT NULL,
    registration_email_url TEXT NOT NULL,
    video_url TEXT,
    start_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_date DATE,
    end_time TIME,
    recurrence TEXT DEFAULT 'Don''t Repeat',
    enable_certification BOOLEAN DEFAULT FALSE
);

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can view events" ON public.events;
CREATE POLICY "Public can view events" ON public.events FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can manage events" ON public.events;
CREATE POLICY "Admins can manage events" ON public.events FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- 4) Refresh schema cache
NOTIFY pgrst, 'reload schema';
