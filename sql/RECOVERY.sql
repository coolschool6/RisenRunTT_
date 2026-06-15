-- RECOVERY: Creates tables if they were dropped
-- Run this in Supabase SQL Editor

-- PROFILES
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
DROP POLICY IF EXISTS "Users read own profile" ON public.profiles;
CREATE POLICY "Users read own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS "Admin all profiles" ON public.profiles;
CREATE POLICY "Admin all profiles" ON public.profiles FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.email), NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- EVENTS
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

-- REGISTRATIONS
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

-- RPC: bypass RLS to get current user's role (used by main.js)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON public.events(start_date);
CREATE INDEX IF NOT EXISTS idx_registrations_user_id ON public.registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_registrations_event_id ON public.registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_proof_status ON public.registrations(proof_status);

-- REFRESH
NOTIFY pgrst, 'reload schema';

-- After this, create user in Dashboard, then:
-- UPDATE public.profiles SET full_name = 'Admin', role = 'admin' WHERE email = 'risenruntt@gmail.com';
