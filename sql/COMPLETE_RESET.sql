-- ============================================================
-- COMPLETE RESET — Run ONCE in Supabase SQL Editor
-- Drops ALL user tables, recreates from scratch, preserves
-- auth.users so you can create the admin user via Dashboard.
-- ============================================================

-- ─── Wipe existing user tables (auth.users is NOT touched) ─
DROP TABLE IF EXISTS public.registrations CASCADE;
DROP TABLE IF EXISTS public.events CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user CASCADE;

-- ─── PROFILES TABLE ─────────────────────────────────────────
CREATE TABLE public.profiles (
  id uuid REFERENCES auth.users PRIMARY KEY,
  full_name text NOT NULL,
  email text NOT NULL,
  role text DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  strava_athlete_id text DEFAULT '',
  strava_connected boolean DEFAULT FALSE,
  created_at timestamp DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admin all profiles" ON public.profiles
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

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

-- ─── EVENTS TABLE ───────────────────────────────────────────
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

CREATE POLICY "Public can view events" ON public.events
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage events" ON public.events
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ─── REGISTRATIONS TABLE ────────────────────────────────────
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

CREATE POLICY "Users read own registrations" ON public.registrations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own registrations" ON public.registrations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own registrations" ON public.registrations
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admin all registrations" ON public.registrations
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ─── STORAGE BUCKETS ────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public) VALUES ('event-banners', 'event-banners', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('proofs', 'proofs', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('screenshots', 'screenshots', true) ON CONFLICT (id) DO NOTHING;

-- Event banners: admins full access, public read
DROP POLICY IF EXISTS "Admins manage event-banners" ON storage.objects;
CREATE POLICY "Admins manage event-banners" ON storage.objects
  FOR ALL USING (
    bucket_id = 'event-banners' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );
DROP POLICY IF EXISTS "Public read event-banners" ON storage.objects;
CREATE POLICY "Public read event-banners" ON storage.objects
  FOR SELECT USING (bucket_id = 'event-banners');

-- Proofs: authenticated users upload/read own, admins read all
DROP POLICY IF EXISTS "Users upload proofs" ON storage.objects;
CREATE POLICY "Users upload proofs" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'proofs' AND auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Users read own proofs" ON storage.objects;
CREATE POLICY "Users read own proofs" ON storage.objects
  FOR SELECT USING (bucket_id = 'proofs' AND auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Admins read all proofs" ON storage.objects;
CREATE POLICY "Admins read all proofs" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'proofs' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Screenshots: same as proofs
DROP POLICY IF EXISTS "Users upload screenshots" ON storage.objects;
CREATE POLICY "Users upload screenshots" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'screenshots' AND auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Users read own screenshots" ON storage.objects;
CREATE POLICY "Users read own screenshots" ON storage.objects
  FOR SELECT USING (bucket_id = 'screenshots' AND auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Admins read all screenshots" ON storage.objects;
CREATE POLICY "Admins read all screenshots" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'screenshots' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ─── INDEXES ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON public.events(start_date);
CREATE INDEX IF NOT EXISTS idx_registrations_user_id ON public.registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_registrations_event_id ON public.registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_proof_status ON public.registrations(proof_status);

-- ─── REFRESH SCHEMA CACHE ───────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- AFTER RUNNING THIS SQL, DO THESE STEPS:
--
-- 1. Go to Supabase Dashboard → Authentication → Users → Add User
--      Email: risenruntt@gmail.com
--      Password: Admin
--      ✅ Auto Confirm User = ON
--      Click "Create user"
--
-- 2. Then run this in SQL Editor:
--    UPDATE public.profiles SET full_name = 'Admin', role = 'admin'
--    WHERE email = 'risenruntt@gmail.com';
--
-- 3. Refresh your browser (Ctrl+F5) and log in.
-- ============================================================
