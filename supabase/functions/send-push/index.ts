type ServiceAccount = { project_id: string; client_email: string; private_key: string };
type Outbox = {
  id: number; recipient_user_id: string | null; send_to_admins: boolean;
  notification_id: string | null; title: string; body: string;
  data: Record<string, unknown>; attempts: number;
};
type Device = { token: string; user_id: string };

const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), {
  status, headers: { 'Content-Type': 'application/json' },
});

function serverKey(): string {
  const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}');
  const key = keys.default ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!key) throw new Error('Server credentials unavailable');
  return key;
}

async function rest(path: string, method = 'GET', body?: unknown): Promise<any> {
  const key = serverKey();
  const headers: Record<string, string> = { apikey: key, 'Content-Type': 'application/json' };
  if (key.startsWith('eyJ')) headers.Authorization = `Bearer ${key}`;
  const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/rest/v1/${path}`, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error(`Database request failed (${response.status})`);
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

function base64Url(bytes: Uint8Array): string {
  let value = '';
  for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

async function googleAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const encode = (value: unknown) => base64Url(new TextEncoder().encode(JSON.stringify(value)));
  const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iss: account.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  })}`;
  const pem = account.private_key.replace(/-----[^-]+-----|\s/g, '');
  const key = await crypto.subtle.importKey(
    'pkcs8', Uint8Array.from(atob(pem), char => char.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${base64Url(new Uint8Array(signature))}`,
    }), signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error(`FCM authorization failed (${response.status})`);
  return (await response.json()).access_token;
}

async function eligible(item: Outbox): Promise<boolean> {
  const noteId = item.data?.note_id;
  if (item.data?.type !== 'reminder' || !noteId) return true;
  const rows = await rest(`promissory_notes?id=eq.${encodeURIComponent(String(noteId))}&select=status,due_date`);
  const note = rows[0];
  if (!note || !['pending', 'overdue'].includes(note.status) || note.due_date !== item.data.due_date) return false;
  const submissions = await rest(`payment_submissions?note_id=eq.${encodeURIComponent(String(noteId))}&status=eq.submitted&select=id&limit=1`);
  return submissions.length === 0;
}

async function deliver(item: Outbox, account: ServiceAccount, bearer: string): Promise<void> {
  if (!await eligible(item)) {
    await rest(`push_outbox?id=eq.${item.id}`, 'PATCH', {
      delivered_at: new Date().toISOString(), locked_until: null, last_error: 'Payment reminder no longer applicable',
    });
    return;
  }
  let recipientFilter: string;
  if (item.send_to_admins) {
    const staff = await rest('profiles?or=(staff_role.in.(accounting,management),and(role.eq.admin,staff_role.is.null))&select=id');
    if (!staff.length) throw new Error('No eligible staff recipients');
    recipientFilter = `user_id=in.(${staff.map((row: { id: string }) => row.id).join(',')})`;
  } else {
    if (!item.recipient_user_id) throw new Error('Missing recipient');
    recipientFilter = `user_id=eq.${item.recipient_user_id}`;
  }
  const devices: Device[] = await rest(`push_devices?${recipientFilter}&select=token,user_id`);
  if (!devices.length) {
    await rest(`push_outbox?id=eq.${item.id}`, 'PATCH', {
      locked_until: null, attempts: Math.max(0, item.attempts - 1),
      next_attempt_at: new Date(Date.now() + 300000).toISOString(), last_error: 'No registered devices',
    });
    return;
  }
  const sent = new Set((await rest(`push_deliveries?outbox_id=eq.${item.id}&select=token`))
    .map((row: { token: string }) => row.token));
  for (const device of devices) {
    if (sent.has(device.token)) continue;
    const current = await rest(`push_devices?token=eq.${encodeURIComponent(device.token)}&user_id=eq.${device.user_id}&select=token`);
    if (!current.length) continue;
    const data = Object.fromEntries(Object.entries({
      ...item.data, recipient_user_id: device.user_id, outbox_id: String(item.id),
    }).filter(([, value]) => value !== null && value !== undefined).map(([key, value]) => [key, String(value)]));
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
      method: 'POST', headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: {
        token: device.token, notification: { title: item.title, body: item.body }, data,
        android: { priority: 'high', ttl: '86400s', notification: {
          channel_id: 'demirturk_updates', icon: 'ic_notification', sound: 'default',
          tag: `demirturk-${item.id}`, visibility: 'PRIVATE',
        } },
        apns: { headers: { 'apns-collapse-id': `demirturk-${item.id}` }, payload: { aps: { sound: 'default' } } },
      } }), signal: AbortSignal.timeout(15000),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      const invalidToken = result.error?.details?.some((detail: { errorCode?: string }) => detail.errorCode === 'UNREGISTERED');
      if (invalidToken) {
        await rest(`push_devices?token=eq.${encodeURIComponent(device.token)}`, 'DELETE');
        continue;
      }
      throw new Error(`FCM delivery failed (${response.status}, ${result.error?.status ?? 'unknown'})`);
    }
    await rest('push_deliveries?on_conflict=outbox_id,token', 'POST', { outbox_id: item.id, token: device.token });
  }
  await rest(`push_outbox?id=eq.${item.id}`, 'PATCH', {
    delivered_at: new Date().toISOString(), locked_until: null, last_error: null,
  });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const configuration = await rest('rpc/push_worker_configuration', 'POST', {
      p_secret: request.headers.get('x-webhook-secret'),
    });
    if (!configuration) return json({ error: 'Unauthorized' }, 401);
    const account: ServiceAccount = configuration.service_account;
    if (!account?.private_key || !account.client_email || !account.project_id) {
      return json({ error: 'Firebase sender configuration is missing' }, 503);
    }
    const payload = await request.json().catch(() => ({}));
    const id = payload?.record?.id ?? payload?.outbox_id ?? null;
    if (id !== null && !/^\d+$/.test(String(id))) return json({ error: 'Invalid outbox id' }, 400);
    const bearer = await googleAccessToken(account);
    let handled = 0;
    for (let index = 0; index < (id === null ? 12 : 1); index++) {
      const rows: Outbox[] = await rest('rpc/claim_push_delivery', 'POST', { p_outbox_id: id });
      if (!rows.length) break;
      const item = rows[0];
      try {
        await deliver(item, account, bearer);
      } catch (error) {
        const delay = Math.min(3600, 30 * 2 ** Math.min(item.attempts, 7));
        await rest(`push_outbox?id=eq.${item.id}`, 'PATCH', {
          locked_until: null, next_attempt_at: new Date(Date.now() + delay * 1000).toISOString(),
          last_error: error instanceof Error ? error.message : 'Delivery failed',
        });
      }
      handled++;
    }
    return json({ handled });
  } catch (error) {
    console.error(error instanceof Error ? error.message : 'Push dispatch failed');
    return json({ error: 'Push dispatcher unavailable' }, 503);
  }
});
