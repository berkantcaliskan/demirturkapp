import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function respond(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function getServerKey(): string | null {
  const keys = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (keys) {
    try {
      const parsed = JSON.parse(keys) as Record<string, string>;
      if (parsed.default) return parsed.default;
    } catch {
      // Fall through to the legacy server-only key.
    }
  }
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? null;
}

function normalizePhone(value: string): string | null {
  let digits = value.replace(/\D/g, '');
  if (digits.startsWith('0090') && digits.length === 14) {
    digits = digits.slice(4);
  } else if (digits.startsWith('90') && digits.length === 12) {
    digits = digits.slice(2);
  } else if (digits.startsWith('0') && digits.length === 11) {
    digits = digits.slice(1);
  }
  return digits.length === 10 && digits.startsWith('5') ? `+90${digits}` : null;
}

async function getStaffPhones(admin: ReturnType<typeof createClient>): Promise<Set<string> | null> {
  const configured = Deno.env.get('STAFF_PHONE_ROSTER');
  if (!configured) {
    const { data, error } = await admin.from('staff_account_roster').select('phone');
    if (error || !data?.length) return null;
    return new Set(data.map((row) => row.phone as string));
  }
  try {
    const rows = JSON.parse(configured) as Array<{ phone?: string }>;
    return new Set(rows.map((row) => normalizePhone(row.phone ?? '')).filter(
      (phone): phone is string => phone !== null,
    ));
  } catch {
    return null;
  }
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const serverKey = getServerKey();
  if (!url || !serverKey) {
    return respond({ error: 'Registration service is not configured' }, 503);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return respond({ error: 'Invalid request' }, 400);
  }

  const phone = normalizePhone(String(payload.phone ?? ''));
  const password = String(payload.password ?? '');
  if (!phone || !/^\d{6}$/.test(password)) {
    return respond({ error: 'Telefon numarası veya parola biçimi geçersiz.' }, 400);
  }
  const admin = createClient(url, serverKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const staffPhones = await getStaffPhones(admin);
  if (!staffPhones) {
    return respond({ error: 'Kayıt servisi şu anda kullanılamıyor.' }, 503);
  }
  if (staffPhones.has(phone)) {
    return respond({ error: 'Bu numara personel girişi için ayrılmış.' }, 403);
  }

  const forwardedFor = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  const clientIp = request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-real-ip') ?? forwardedFor ?? 'unknown';
  const [phoneHash, ipHash] = await Promise.all([
    sha256(phone),
    sha256(clientIp),
  ]);

  const { data: reservedStaff, error: rosterError } = await admin
    .from('profiles')
    .select('id')
    .eq('contact_phone', phone)
    .not('staff_role', 'is', null)
    .maybeSingle();
  if (rosterError) {
    console.error('Staff username check failed:', rosterError.message);
    return respond({ error: 'Kayıt servisi şu anda kullanılamıyor.' }, 503);
  }
  if (reservedStaff) {
    return respond({ error: 'Bu numara personel girişi için ayrılmış.' }, 403);
  }

  const { data: permitted, error: limitError } = await admin.rpc(
    'consume_phone_signup_rate_limit',
    { p_phone_hash: phoneHash, p_ip_hash: ipHash },
  );
  if (limitError) {
    console.error('Signup rate-limit check failed:', limitError.message);
    return respond({ error: 'Kayıt servisi şu anda kullanılamıyor.' }, 503);
  }
  if (permitted !== true) {
    return respond({ error: 'Çok fazla kayıt denemesi. Lütfen daha sonra tekrar deneyin.' }, 429);
  }

  // The client never receives a server key. The phone is marked confirmed only
  // so password sign-in works without SMS; contract ownership is handled by a
  // separate trusted management action, not by matching this unverified value.
  const { error } = await admin.auth.admin.createUser({
    phone,
    password,
    phone_confirm: true,
    user_metadata: {
      full_name: 'Müşteri',
      username_phone: phone,
      registration_method: 'phone_username_password',
    },
  });
  if (error) {
    const isExisting = /already|exists|duplicate/i.test(error.message);
    return respond({
      error: isExisting
        ? 'Bu numarayla bir hesap zaten var. Giriş yapmayı deneyin.'
        : 'Hesap oluşturulamadı. Bilgilerinizi kontrol edip tekrar deneyin.',
    }, isExisting ? 409 : 400);
  }

  return respond({ ok: true });
});
