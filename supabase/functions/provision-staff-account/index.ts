import { createClient, type User } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-staff-provisioning-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const staffRoster = new Map([
  ['ertuğrul', { fullName: 'Ertuğrul', staffRole: 'sales_advisor' }],
  ['levent', { fullName: 'Levent', staffRole: 'sales_advisor' }],
  ['hazal', { fullName: 'Hazal', staffRole: 'sales_advisor' }],
  ['özlem', { fullName: 'Özlem', staffRole: 'accounting' }],
  ['berkant', { fullName: 'Berkant', staffRole: 'management' }],
  ['murat', { fullName: 'Murat', staffRole: 'management' }],
]);

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
  if (digits.startsWith('0090') && digits.length === 14) digits = digits.slice(4);
  else if (digits.startsWith('90') && digits.length === 12) digits = digits.slice(2);
  else if (digits.startsWith('0') && digits.length === 11) digits = digits.slice(1);
  return digits.length === 10 && digits.startsWith('5') ? `+90${digits}` : null;
}

async function isRosterPhone(admin: ReturnType<typeof createClient>, name: string, phone: string): Promise<boolean> {
  const configured = Deno.env.get('STAFF_PHONE_ROSTER');
  if (!configured) {
    const { data, error } = await admin.from('staff_account_roster')
      .select('name').eq('name', name).eq('phone', phone).maybeSingle();
    return !error && data !== null;
  }
  try {
    const rows = JSON.parse(configured) as Array<{ name?: string; phone?: string }>;
    return rows.some((row) =>
      String(row.name ?? '').trim().toLocaleLowerCase('tr-TR') === name &&
      normalizePhone(row.phone ?? '') === phone
    );
  } catch {
    return false;
  }
}

function sameSecret(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index++) difference |= a[index] ^ b[index];
  return difference === 0;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const serverKey = getServerKey();
  if (!url || !serverKey) return respond({ error: 'Provisioning service is not configured' }, 503);
  const admin = createClient(url, serverKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const expectedSecret = Deno.env.get('STAFF_PROVISIONING_SECRET') ?? '';
  const suppliedSecret = request.headers.get('x-staff-provisioning-key') ?? '';
  let permitted = expectedSecret.length >= 32 && sameSecret(suppliedSecret, expectedSecret);
  if (!permitted && suppliedSecret.length >= 32) {
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(suppliedSecret));
    const keyHash = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
    const { data, error } = await admin.from('staff_provisioning_access')
      .select('key_hash').eq('key_hash', keyHash)
      .gt('expires_at', new Date().toISOString()).maybeSingle();
    permitted = !error && data !== null;
  }
  if (!permitted) return respond({ error: 'Unauthorized' }, 401);

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return respond({ error: 'Invalid request' }, 400);
  }

  const rosterKey = String(payload.name ?? '').trim().toLocaleLowerCase('tr-TR');
  const employee = staffRoster.get(rosterKey);
  const phone = normalizePhone(String(payload.phone ?? ''));
  const password = String(payload.password ?? '');
  if (!employee || !phone || !/^\d{6}$/.test(password)) {
    return respond({ error: 'Personel adı, telefon numarası veya parola biçimi geçersiz.' }, 400);
  }
  if (!await isRosterPhone(admin, rosterKey, phone)) {
    return respond({ error: 'Bu ad ve numara personel listesiyle eşleşmiyor.' }, 403);
  }

  let user: User | null = null;
  for (let page = 1; ; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) {
      console.error('Could not search staff accounts:', error.message);
      return respond({ error: 'Personel hesabı aranamadı.' }, 503);
    }
    user = data.users.find((candidate) => normalizePhone(candidate.phone ?? '') === phone) ?? null;
    if (user || data.users.length < 1000) break;
  }

  const attributes = {
    phone,
    password,
    phone_confirm: true,
    user_metadata: {
      full_name: employee.fullName,
      username_phone: phone,
      registration_method: 'staff_provisioning',
    },
  };
  if (user) {
    const { error } = await admin.auth.admin.updateUserById(user.id, attributes);
    if (error) {
      console.error('Could not update staff Auth user:', error.message);
      return respond({ error: 'Personel hesabı güncellenemedi.' }, 400);
    }
  } else {
    const { data, error } = await admin.auth.admin.createUser(attributes);
    if (error || !data.user) {
      console.error('Could not create staff Auth user:', error?.message);
      return respond({ error: 'Personel hesabı oluşturulamadı.' }, 400);
    }
    user = data.user;
  }

  const { error: profileError } = await admin.from('profiles').upsert({
    id: user.id,
    full_name: employee.fullName,
    staff_role: employee.staffRole,
    contact_phone: phone,
  }, { onConflict: 'id' });
  if (profileError) {
    console.error('Could not assign staff profile:', profileError.message);
    return respond({ error: 'Hesap açıldı ancak personel rolü atanamadı; yeniden deneyin.' }, 500);
  }

  const { data: profile, error: readError } = await admin
    .from('profiles')
    .select('staff_id')
    .eq('id', user.id)
    .single();
  if (readError) {
    console.error('Could not read generated staff ID:', readError.message);
    return respond({ error: 'Personel ID bilgisi okunamadı.' }, 500);
  }

  return respond({ ok: true, name: employee.fullName, role: employee.staffRole, staff_id: profile.staff_id });
});
