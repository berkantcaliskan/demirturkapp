export type SyncCandidate = { customer_id: string; plan_ids: string[]; version: string }
export function createFinanceWorker(deps: {
  secret: string; claim: () => Promise<SyncCandidate[]>;
  sync: (candidate: SyncCandidate) => Promise<void>;
}) {
  return async (req: Request) => {
    const reply = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } })
    if (req.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    if (deps.secret.length < 32) return reply({ error: 'worker_not_configured' }, 503)
    const hash = async (value: string) => new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))
    const [a, b] = await Promise.all([hash(deps.secret), hash(req.headers.get('x-cron-key') ?? '')])
    let mismatch = 0
    for (let i = 0; i < a.length; i++) mismatch |= a[i] ^ b[i]
    if (mismatch) return reply({ error: 'unauthorized' }, 401)
    try {
      const candidates = await deps.claim()
      if (candidates.length > 20) return reply({ error: 'invalid_batch' }, 503)
      let next = 0, completed = 0, failed = 0
      await Promise.all(Array.from({ length: Math.min(5, candidates.length) }, async () => {
        for (;;) {
          const candidate = candidates[next++]
          if (!candidate) return
          try { await deps.sync(candidate); completed++ } catch { failed++ }
        }
      }))
      // No identifiers, customer data, keys or upstream exception text in worker responses.
      return reply({ completed, failed }, failed ? 207 : 200)
    } catch { return reply({ error: 'finance_source_unavailable' }, 503) }
  }
}
