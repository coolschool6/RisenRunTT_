-- Run this in Supabase SQL Editor

-- ============================================================
-- PROFILES TABLE (syncs with auth.users via trigger)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid REFERENCES auth.users PRIMARY KEY,
  full_name text NOT NULL,
  email text NOT NULL,
  role text DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  strava_athlete_id text DEFAULT '',
  strava_connected boolean DEFAULT FALSE,
  created_at timestamp DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own profile
CREATE POLICY "Users read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- Allow admin full access
CREATE POLICY "Admin all profiles" ON public.profiles
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Allow users to update their own profile (needed for Strava toggle, etc.)
CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Auto-insert profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (new.id, COALESCE(new.raw_user_meta_data ->> 'full_name', new.email), new.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- EVENTS TABLE (aligned with admin_create_event.html)
-- ============================================================
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

-- Public read access
CREATE POLICY "Public can view events" ON public.events
    FOR SELECT USING (true);

-- Admin full access
CREATE POLICY "Admins can manage events" ON public.events
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

-- ============================================================
-- REGISTRATIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.registrations (
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

-- Users read own registrations
CREATE POLICY "Users read own registrations" ON public.registrations
  FOR SELECT USING (auth.uid() = user_id);

-- Users insert own registrations
CREATE POLICY "Users insert own registrations" ON public.registrations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admin full access
CREATE POLICY "Admin all registrations" ON public.registrations
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ============================================================
-- MIGRATION: Add columns if table already exists (safe to run again)
-- ============================================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS strava_athlete_id TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS strava_connected BOOLEAN DEFAULT FALSE;

ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS proof_status TEXT DEFAULT 'Not Submitted';
ALTER TABLE public.registrations DROP CONSTRAINT IF EXISTS registrations_proof_status_check;
ALTER TABLE public.registrations ADD CONSTRAINT registrations_proof_status_check CHECK (proof_status IN ('Not Submitted', 'Pending', 'Approved', 'Rejected'));
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1;
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS billing_first_name TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS billing_last_name TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS billing_phone TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS billing_email TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS attendee_first_name TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS attendee_last_name TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS attendee_phone TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS attendee_location TEXT DEFAULT '';

-- Drop old CHECK constraints on registrations.status
ALTER TABLE public.registrations DROP CONSTRAINT IF EXISTS registrations_status_check;
-- Add updated constraint allowing 'Registered'
ALTER TABLE public.registrations ADD CONSTRAINT registrations_status_check CHECK (status IN ('Registered', 'Approved', 'Rejected'));

-- Drop old columns from the old schema if they still exist
ALTER TABLE public.events DROP COLUMN IF EXISTS date;
ALTER TABLE public.events DROP COLUMN IF EXISTS time;
ALTER TABLE public.events DROP COLUMN IF EXISTS venue;
ALTER TABLE public.events DROP COLUMN IF EXISTS registration_email;

-- ============================================================
-- POST-SETUP INSTRUCTIONS
-- Run these after creating your account
-- ============================================================

-- 1. Backfill profiles for users who signed up BEFORE the trigger existed:
INSERT INTO public.profiles (id, full_name, email)
SELECT id, COALESCE(raw_user_meta_data->>'full_name', email), email
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 2. Promote yourself to admin (replace with your email):
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'your-email@example.com';

-- ============================================================
-- INDEXES (for performance)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON public.events(start_date);
CREATE INDEX IF NOT EXISTS idx_registrations_user_id ON public.registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_registrations_event_id ON public.registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_proof_status ON public.registrations(proof_status);

-- ============================================================
-- POST-SETUP INSTRUCTIONS
-- ============================================================

-- 3. Verify admin status:
-- SELECT p.id, p.email, p.role, p.created_at FROM public.profiles p WHERE p.role = 'admin';

-- ============================================================
-- STORAGE BUCKET POLICIES (run after creating buckets in UI)
-- ============================================================

-- Event banners: admins full access, public read
CREATE POLICY "Admins manage event-banners" ON storage.objects
  FOR ALL USING (
    bucket_id = 'event-banners' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );
CREATE POLICY "Public read event-banners" ON storage.objects
  FOR SELECT USING (bucket_id = 'event-banners');

-- Proofs: authenticated users upload/read own, admins read all
CREATE POLICY "Users upload proofs" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'proofs' AND auth.role() = 'authenticated');
CREATE POLICY "Users read own proofs" ON storage.objects
  FOR SELECT USING (bucket_id = 'proofs' AND auth.role() = 'authenticated');
CREATE POLICY "Admins read all proofs" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'proofs' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Screenshots: same as proofs
CREATE POLICY "Users upload screenshots" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'screenshots' AND auth.role() = 'authenticated');
CREATE POLICY "Users read own screenshots" ON storage.objects
  FOR SELECT USING (bucket_id = 'screenshots' AND auth.role() = 'authenticated');
CREATE POLICY "Admins read all screenshots" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'screenshots' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ============================================================
-- FINAL: Refresh PostgREST schema cache
-- ============================================================
NOTIFY pgrst, 'reload schema';
