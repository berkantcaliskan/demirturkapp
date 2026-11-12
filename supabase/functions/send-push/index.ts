const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-webhook-secret',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function pemBytes(pem: string): Uint8Array {
  const body = pem.replace(/-----[^-]+-----/g, '').replaceAll(/\s/g, '');
  return Uint8Array.from(atob(body), (char) => char.charCodeAt(0));
}

function getSupabaseServerKey(): string {
  // Supabase injects the new secret API keys as a name-to-key JSON map.
  // Keep the legacy variable as a migration fallback for existing projects.
  const secretKeys = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (secretKeys) {
    const keys = JSON.parse(secretKeys) as Record<string, string>;
    if (keys.default) return keys.default;
  }
  const legacyKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (legacyKey) return legacyKey;
  throw new Error('Supabase server key is not configured');
}

async function accessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const enc = new TextEncoder();
  const header = base64Url(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claim = base64Url(enc.encode(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })));
  const unsigned = `${header}.${claim}`;
  const privateKey = await crypto.subtle.importKey(
    'pkcs8', pemBytes(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', privateKey, enc.encode(unsigned)));
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const response = await fetch(serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const body = await response.json();
  if (!response.ok) throw new Error(`Google OAuth: ${JSON.stringify(body)}`);
  return body.access_token as string;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const hookSecret = Deno.env.get('PUSH_WEBHOOK_SECRET');
  if (!hookSecret || request.headers.get('x-webhook-secret') !== hookSecret) {
    return json({ error: 'Unauthorized webhook' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serverKey = getSupabaseServerKey();
  const serviceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? '{}');
  if (!serviceAccount.private_key || !serviceAccount.client_email) {
    return json({ error: 'FCM service account is not configured' }, 503);
  }
  const payload = await request.json();
  const outboxId = payload?.record?.id ?? payload?.outbox_id;
  if (!outboxId) return json({ error: 'Missing outbox record id' }, 400);
  // Secret API keys are not JWTs; pass them through apikey only.
  const headers = { apikey: serverKey };
  const rowResponse = await fetch(`${supabaseUrl}/rest/v1/push_outbox?id=eq.${outboxId}&select=*`, { headers });
  const rows = await rowResponse.json();
  const item = rows?.[0];
  if (!item) return json({ error: 'Outbox item not found' }, 404);
  if (item.delivered_at) return json({ delivered: true, duplicate: true });

  let query: string;
  if (item.send_to_admins) {
    const adminResponse = await fetch(`${supabaseUrl}/rest/v1/profiles?role=eq.admin&select=id`, { headers });
    const admins = await adminResponse.json();
    const ids = admins.map((admin: { id: string }) => admin.id);
    if (ids.length === 0) return json({ delivered: false, reason: 'no_admins' }, 202);
    query = `${supabaseUrl}/rest/v1/push_devices?user_id=in.(${ids.join(',')})&select=token,user_id`;
  } else {
    query = `${supabaseUrl}/rest/v1/push_devices?user_id=eq.${item.recipient_user_id}&select=token,user_id`;
  }
  const devicesResponse = await fetch(query, { headers });
  const devices = await devicesResponse.json();
  if (!devicesResponse.ok) throw new Error(`Device lookup failed: ${JSON.stringify(devices)}`);
  if (devices.length === 0) {
    await fetch(`${supabaseUrl}/rest/v1/push_outbox?id=eq.${outboxId}`, {
      method: 'PATCH', headers: { ...headers, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: JSON.stringify({ attempts: item.attempts + 1, last_error: 'Recipient has no registered push devices' }),
    });
    return json({ delivered: false, reason: 'no_devices' }, 202);
  }

  const bearer = await accessToken(serviceAccount);
  const projectId = serviceAccount.project_id;
  const results = await Promise.all(devices.map(async (device: { token: string }) => {
    const result = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: 'POST', headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: device.token,
          notification: { title: item.title, body: item.body },
          data: Object.fromEntries(Object.entries(item.data ?? {}).map(([key, value]) => [key, String(value)])),
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    });
    const responseBody = await result.json().catch(() => ({}));
    if (!result.ok && JSON.stringify(responseBody).includes('UNREGISTERED')) {
      await fetch(`${supabaseUrl}/rest/v1/push_devices?token=eq.${encodeURIComponent(device.token)}`, {
        method: 'DELETE', headers,
      });
    }
    return { ok: result.ok, responseBody };
  }));
  const failures = results.filter((result) => !result.ok);
  await fetch(`${supabaseUrl}/rest/v1/push_outbox?id=eq.${outboxId}`, {
    method: 'PATCH', headers: { ...headers, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify(failures.length === 0
      ? { delivered_at: new Date().toISOString(), attempts: item.attempts + 1, last_error: null }
      : { attempts: item.attempts + 1, last_error: JSON.stringify(failures).slice(0, 2000) }),
  });
  return json({ delivered: failures.length === 0, device_count: devices.length, failures: failures.length }, failures.length ? 502 : 200);
});
