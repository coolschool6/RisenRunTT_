-- ============================================================
-- Confirmation Email Trigger
-- Deploy the Edge Function first, then run this SQL.
-- Set RESEND_API_KEY secret in Supabase Dashboard:
--   Edge Functions → send-confirmation → Secrets → Add
-- ============================================================

-- Create the Edge Function hook
-- NOTE: Replace 'https://yfyopxzdvyntjnocnzpi.supabase.co' with your actual project URL
CREATE OR REPLACE FUNCTION public.handle_registration_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM
    net.http_post(
      url := 'https://yfyopxzdvyntjnocnzpi.supabase.co/functions/v1/send-confirmation',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('request.jwt.claim.sub', true)
      ),
      body := jsonb_build_object(
        'type', 'INSERT',
        'table', 'registrations',
        'record', row_to_json(NEW)::jsonb
      )
    );
  RETURN NEW;
END;
$$;

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS on_registration_insert ON public.registrations;

-- Create the trigger
CREATE TRIGGER on_registration_insert
  AFTER INSERT ON public.registrations
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_registration_email();

-- ============================================================
-- TO DEPLOY THE EDGE FUNCTION:
-- 1. Go to Supabase Dashboard → Edge Functions → Create Function
-- 2. Name it "send-confirmation"
-- 3. Copy-paste the contents of supabase/functions/send-confirmation/index.ts
-- 4. Set secret: RESEND_API_KEY (get one from https://resend.com)
-- 5. Deploy
-- ============================================================
