// Supabase Edge Function: send-confirmation
// Deploy via: Supabase Dashboard → Edge Functions → Create Function
// Set secret RESEND_API_KEY in Supabase Dashboard (Edge Functions → send-confirmation → Secrets)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

interface RegistrationPayload {
  type: 'INSERT';
  table: string;
  record: {
    id: string;
    user_id: string;
    event_id: string;
    attendee_first_name: string;
    attendee_last_name: string;
    billing_email: string;
  };
}

const RESEND_API_KEY = 're_2ZqHKTBy_PCfVwst6DghYSyZPYPYBUH5o';

serve(async (req: Request) => {
  try {
    const payload: RegistrationPayload = await req.json();

    if (payload.type !== 'INSERT' || payload.table !== 'registrations') {
      return new Response('Not a registration insert', { status: 200 });
    }

    const { record } = payload;

    // Fetch event details
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const res = await fetch(`${supabaseUrl}/rest/v1/events?id=eq.${record.event_id}`, {
      headers: { apikey: supabaseKey }
    });
    const events = await res.json();
    const event = events?.[0];
    if (!event) return new Response('Event not found', { status: 404 });

    const runnerName = `${record.attendee_first_name || ''} ${record.attendee_last_name || ''}`.trim() || 'Runner';

    const emailRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'onboarding@resend.dev',
        to: record.billing_email || 'israelmayr2008@gmail.com',
        subject: `Registration Confirmed: ${event.title}`,
        html: `
          <div style="font-family:sans-serif;max-width:560px;margin:0 auto;">
            <h1 style="color:#8b0000;">Registration Confirmed!</h1>
            <p>Thank you, <strong>${runnerName}</strong>.</p>
            <p>You are registered for <strong>${event.title}</strong>.</p>
            <table style="width:100%;border-collapse:collapse;margin:16px 0;">
              <tr><td style="padding:8px;border-bottom:1px solid #ddd;font-weight:700;color:#333;">Event</td><td style="padding:8px;border-bottom:1px solid #ddd;">${event.title}</td></tr>
              <tr><td style="padding:8px;border-bottom:1px solid #ddd;font-weight:700;color:#333;">Date</td><td style="padding:8px;border-bottom:1px solid #ddd;">${event.start_date || 'TBD'}${event.start_time ? ' at ' + event.start_time : ''}</td></tr>
              ${event.location ? `<tr><td style="padding:8px;border-bottom:1px solid #ddd;font-weight:700;color:#333;">Location</td><td style="padding:8px;border-bottom:1px solid #ddd;">${event.location}</td></tr>` : ''}
            </table>
            <p style="color:#666;font-size:0.9rem;">Log in to your dashboard to view your registrations and submit proof of completion.</p>
            <a href="${supabaseUrl.replace('.supabase.co', '')}/dashboard.html" style="display:inline-block;padding:12px 28px;background:#8b0000;color:white;text-decoration:none;border-radius:30px;font-weight:700;">My Dashboard</a>
          </div>
        `,
      }),
    });

    const result = await emailRes.text();
    console.log('Email result:', result);

    return new Response('OK', { status: 200 });
  } catch (err) {
    console.error('Error:', err);
    return new Response(err.message, { status: 500 });
  }
});
