-- ============================================================
-- MASTER SETUP — RUN THIS FIRST in Supabase SQL Editor
-- Drops & recreates ALL tables, sets up RLS, RPC, storage.
-- Preserves auth.users — you keep existing accounts.
-- ============================================================

-- ─── WIPE existing user tables (auth.users is NOT touched) ─
DROP TABLE IF EXISTS public.registrations CASCADE;
DROP TABLE IF EXISTS public.events CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user CASCADE;

-- ============================================================
-- PROFILES TABLE
-- ============================================================
CREATE TABLE public.profiles (
  id uuid REFERENCES auth.users PRIMARY KEY,
  full_name text NOT NULL,
  email text NOT NULL,
  role text DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  avatar_url text DEFAULT '',
  bio text DEFAULT '',
  date_of_birth date DEFAULT NULL,
  strava_athlete_id text DEFAULT '',
  strava_connected boolean DEFAULT FALSE,
  strava_access_token text DEFAULT '',
  strava_refresh_token text DEFAULT '',
  strava_expires_at bigint DEFAULT 0,
  created_at timestamp DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Use SECURITY DEFINER RPC for admin checks to avoid recursion
-- So we keep RLS simple: users read/update own profile only
CREATE POLICY "Users read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Admin all access via get_my_role() RPC (bypasses RLS)
-- Note: the "Admin all profiles" policy uses get_my_role() which is SECURITY DEFINER
CREATE POLICY "Admin all profiles" ON public.profiles
  FOR ALL USING (public.get_my_role() = 'admin');

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.email),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- EVENTS TABLE
-- ============================================================
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
    recurrence_parent_id UUID DEFAULT NULL,
    enable_certification BOOLEAN DEFAULT FALSE,
    max_participants INTEGER DEFAULT NULL
);

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view events" ON public.events
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage events" ON public.events
  FOR ALL USING (public.get_my_role() = 'admin');

-- ============================================================
-- REGISTRATIONS TABLE
-- ============================================================
CREATE TABLE public.registrations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  event_id uuid REFERENCES public.events NOT NULL,
  status text DEFAULT 'Registered' CHECK (status IN ('Registered', 'Approved', 'Rejected', 'Cancelled')),
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

CREATE POLICY "Users read own registrations" ON public.registrations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own registrations" ON public.registrations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own registrations" ON public.registrations
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admin all registrations" ON public.registrations
  FOR ALL USING (public.get_my_role() = 'admin');

-- ============================================================
-- WAITLIST TABLE (Feature 7)
-- ============================================================
CREATE TABLE public.waitlist (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id uuid REFERENCES public.events NOT NULL,
  user_id uuid REFERENCES auth.users NOT NULL,
  notified BOOLEAN DEFAULT FALSE,
  created_at timestamp DEFAULT now(),
  UNIQUE(event_id, user_id)
);

ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own waitlist" ON public.waitlist
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Admin all waitlist" ON public.waitlist
  FOR ALL USING (public.get_my_role() = 'admin');

-- ============================================================
-- RESULTS TABLE (Feature 2 — Leaderboard)
-- ============================================================
CREATE TABLE public.results (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id uuid REFERENCES public.events NOT NULL,
  user_id uuid REFERENCES auth.users,
  full_name TEXT NOT NULL,
  time_formatted TEXT NOT NULL,
  distance TEXT DEFAULT '',
  position INTEGER DEFAULT 0,
  source TEXT DEFAULT 'manual' CHECK (source IN ('manual', 'strava', 'csv')),
  proof_status TEXT DEFAULT 'approved' CHECK (proof_status IN ('approved', 'pending', 'rejected')),
  created_at timestamp DEFAULT now()
);

ALTER TABLE public.results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read results" ON public.results
  FOR SELECT USING (true);

CREATE POLICY "Admin all results" ON public.results
  FOR ALL USING (public.get_my_role() = 'admin');

-- ============================================================
-- STRAVA ACTIVITIES TABLE (Feature 1)
-- ============================================================
CREATE TABLE public.strava_activities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  strava_activity_id bigint NOT NULL UNIQUE,
  name TEXT DEFAULT '',
  distance numeric(10,2) DEFAULT 0,
  moving_time integer DEFAULT 0,
  activity_date timestamp DEFAULT now(),
  imported_at timestamp DEFAULT now()
);

ALTER TABLE public.strava_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own activities" ON public.strava_activities
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own activities" ON public.strava_activities
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admin all activities" ON public.strava_activities
  FOR ALL USING (public.get_my_role() = 'admin');

-- ============================================================
-- RPC FUNCTION: get_my_role (SECURITY DEFINER = bypasses RLS)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public) VALUES ('event-banners', 'event-banners', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('proofs', 'proofs', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;

-- Event banners: public read, admin manage
DROP POLICY IF EXISTS "Admins manage event-banners" ON storage.objects;
CREATE POLICY "Admins manage event-banners" ON storage.objects
  FOR ALL USING (
    bucket_id = 'event-banners' AND public.get_my_role() = 'admin'
  );

DROP POLICY IF EXISTS "Public read event-banners" ON storage.objects;
CREATE POLICY "Public read event-banners" ON storage.objects
  FOR SELECT USING (bucket_id = 'event-banners');

-- Proofs: auth upload/read, admin read all
DROP POLICY IF EXISTS "Users upload proofs" ON storage.objects;
CREATE POLICY "Users upload proofs" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'proofs' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users read own proofs" ON storage.objects;
CREATE POLICY "Users read own proofs" ON storage.objects
  FOR SELECT USING (bucket_id = 'proofs' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins read all proofs" ON storage.objects;
CREATE POLICY "Admins read all proofs" ON storage.objects
  FOR SELECT USING (bucket_id = 'proofs' AND public.get_my_role() = 'admin');

-- Avatars: public read, auth upload own
DROP POLICY IF EXISTS "Public read avatars" ON storage.objects;
CREATE POLICY "Public read avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Auth upload avatars" ON storage.objects;
CREATE POLICY "Auth upload avatars" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins manage avatars" ON storage.objects;
CREATE POLICY "Admins manage avatars" ON storage.objects
  FOR ALL USING (
    bucket_id = 'avatars' AND public.get_my_role() = 'admin'
  );

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON public.events(start_date);
CREATE INDEX IF NOT EXISTS idx_registrations_user_id ON public.registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_registrations_event_id ON public.registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_proof_status ON public.registrations(proof_status);
CREATE INDEX IF NOT EXISTS idx_results_event_id ON public.results(event_id);
CREATE INDEX IF NOT EXISTS idx_waitlist_event_id ON public.waitlist(event_id);

-- ============================================================
-- REFRESH SCHEMA CACHE
-- ============================================================
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- AFTER RUNNING THIS SQL:
--
-- 1. Go to Supabase Dashboard → Authentication → Users → Add User
--      Email: risenruntt@gmail.com
--      Password: Admin
--      ✅ Auto Confirm User = ON
--      Click "Create user"
--
-- 2. Run this in SQL Editor:
--    UPDATE public.profiles SET full_name = 'Admin', role = 'admin'
--    WHERE email = 'risenruntt@gmail.com';
--
-- 3. Verify it worked:
--    SELECT id, email, full_name, role FROM public.profiles WHERE role = 'admin';
--
-- 4. Refresh your browser (Ctrl+F5) and log in at /login.html
-- ============================================================
