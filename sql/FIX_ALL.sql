-- Run ALL of this in Supabase SQL Editor.
-- Shows exactly what's in the database, then fixes everything.

-- ============================
-- PART 1: DIAGNOSTIC
-- ============================
SELECT '--- AUTH USERS ---' AS info;
SELECT id, email, raw_user_meta_data FROM auth.users;

SELECT '--- PROFILES ---' AS info;
SELECT id, email, full_name, role FROM public.profiles;

SELECT '--- TABLES ---' AS info;
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- ============================
-- PART 2: RECREATE EVENTS TABLE
-- ============================
DROP TABLE IF EXISTS public.registrations CASCADE;
DROP TABLE IF EXISTS public.events CASCADE;

CREATE TABLE public.events (
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

-- ============================
-- PART 3: RECREATE REGISTRATIONS TABLE
-- ============================
CREATE TABLE public.registrations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  event_id uuid REFERENCES public.events NOT NULL,
  status text DEFAULT 'Registered' CHECK (status IN ('Registered', 'Approved', 'Rejected')),
  proof_status text DEFAULT 'Not Submitted' CHECK (proof_status IN ('Not Submitted', 'Pending', 'Approved', 'Rejected')),
  screenshot_url text DEFAULT '',
  quantity integer DEFAULT 1,
  billing_first_name text DEFAULT '',
  billing_last_name text DEFAULT '',
  billing_phone text DEFAULT '',
  billing_email text DEFAULT '',
  attendee_first_name text DEFAULT '',
  attendee_last_name text DEFAULT '',
  attendee_phone text DEFAULT '',
  attendee_location text DEFAULT '',
  created_at timestamp DEFAULT now()
);

ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read own registrations" ON public.registrations;
CREATE POLICY "Users read own registrations" ON public.registrations FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users insert own registrations" ON public.registrations;
CREATE POLICY "Users insert own registrations" ON public.registrations FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users update own registrations" ON public.registrations;
CREATE POLICY "Users update own registrations" ON public.registrations FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Admin all registrations" ON public.registrations;
CREATE POLICY "Admin all registrations" ON public.registrations FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ============================
-- PART 4: RPC FUNCTION
-- ============================
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- ============================
-- PART 5: SET ADMIN ROLE (uses ID from diagnostic above)
-- Replace 'CHANGE-ME' with the actual UUID from PART 1 output
-- ============================
-- UPDATE public.profiles SET full_name = 'Admin', role = 'admin' WHERE id = 'CHANGE-ME';

-- ============================
-- PART 6: REFRESH SCHEMA CACHE
-- ============================
NOTIFY pgrst, 'reload schema';

-- ============================
-- PART 7: VERIFY
-- ============================
SELECT '--- AFTER FIX ---' AS info;
SELECT id, email, full_name, role FROM public.profiles;
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
