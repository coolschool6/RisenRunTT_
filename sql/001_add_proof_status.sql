-- Run this in Supabase SQL Editor
-- If you get "column proof_status of relation registrations does not exist"
-- or registrations show as zero in admin dashboard:

-- 1) Add the missing columns (safe to re-run)
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS proof_status TEXT DEFAULT 'Not Submitted';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1;
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS billing_first_name TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS billing_last_name TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS billing_phone TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS billing_email TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS attendee_first_name TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS attendee_last_name TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS attendee_phone TEXT DEFAULT '';
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS attendee_location TEXT DEFAULT '';

-- 2) Add CHECK constraint for proof_status
ALTER TABLE public.registrations DROP CONSTRAINT IF EXISTS registrations_proof_status_check;
ALTER TABLE public.registrations ADD CONSTRAINT registrations_proof_status_check CHECK (proof_status IN ('Not Submitted', 'Pending', 'Approved', 'Rejected'));

-- 3) Fix status CHECK constraint to allow 'Registered'
ALTER TABLE public.registrations DROP CONSTRAINT IF EXISTS registrations_status_check;
ALTER TABLE public.registrations ADD CONSTRAINT registrations_status_check CHECK (status IN ('Registered', 'Approved', 'Rejected'));

-- 4) Enable RLS if not already enabled
ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;

-- 5) Create RLS policies (safe to re-run)
DROP POLICY IF EXISTS "Users read own registrations" ON public.registrations;
CREATE POLICY "Users read own registrations" ON public.registrations
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own registrations" ON public.registrations;
CREATE POLICY "Users insert own registrations" ON public.registrations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own registrations" ON public.registrations;
CREATE POLICY "Users update own registrations" ON public.registrations
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin all registrations" ON public.registrations;
CREATE POLICY "Admin all registrations" ON public.registrations
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 6) Enable RLS on profiles if not already
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 7) Create profiles policies if missing
DROP POLICY IF EXISTS "Users read own profile" ON public.profiles;
CREATE POLICY "Users read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admin all profiles" ON public.profiles;
CREATE POLICY "Admin all profiles" ON public.profiles
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 8) Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
