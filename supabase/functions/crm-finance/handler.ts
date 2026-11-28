export type Actor = { id: string; canManage: boolean }
export type FinanceContext = { planIds: string[]; version: string; importedAt?: string } | null
export type BridgeDependencies = {
  authenticate: (authorization: string) => Promise<Actor | null>;
  context: (customerId: string) => Promise<FinanceContext>;
  source: (body: Record<string, unknown>) => Promise<any>;
  apply: (args: { actorId: string; customerId: string; planIds: string[]; version: string | null; snapshot: unknown; relink: boolean }) => Promise<unknown>;
}
export class BridgeError extends Error {
  code: string;
  status: number;
  constructor(code: string, status = 503) { super(code); this.code = code; this.status = status }
}
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i
const headers = {
  'Content-Type': 'application/json', 'Cache-Control': 'no-store',
  'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const reply = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers })
export async function boundedJson(input: Request | Response, limit: number): Promise<any> {
  const reader = input.body?.getReader()
  if (!reader) throw new BridgeError('invalid_request', 400)
  const decoder = new TextDecoder(), parts: string[] = []
  let size = 0
  try {
    for (;;) {
      const chunk = await reader.read()
      if (chunk.done) break
      size += chunk.value.byteLength
      if (size > limit) { await reader.cancel(); throw new BridgeError('response_too_large', 413) }
      parts.push(decoder.decode(chunk.value, { stream: true }))
    }
    parts.push(decoder.decode())
    return JSON.parse(parts.join(''))
  } finally { reader.releaseLock() }
}
export function validateSnapshot(value: any, planIds: string[]) {
  if (!value || value.schemaVersion !== 1 || value.currency !== 'TRY' || value.source !== 'e-demirturk'
    || !Number.isFinite(Date.parse(value.asOf)) || !Array.isArray(value.contracts) || value.contracts.length !== planIds.length) throw new BridgeError('invalid_source_data')
  const ids = new Set(planIds)
  const money = (n: unknown) => typeof n === 'number' && Number.isSafeInteger(n) && n >= 0 && n <= 99_999_999_999_999
  for (const contract of value.contracts) {
    if (!ids.delete(contract.sourceId) || ![contract.totalCents, contract.paidCents, contract.remainingCents].every(money)
      || contract.totalCents !== contract.paidCents + contract.remainingCents || !Array.isArray(contract.notes)
      || contract.notes.length < 1 || contract.notes.length > 360 || !Array.isArray(contract.payments)) throw new BridgeError('invalid_source_data')
    const notes = new Set<string>()
    for (const [index, note] of contract.notes.entries()) {
      if (typeof note.sourceId !== 'string' || notes.has(note.sourceId) || note.number !== index + 1
        || !money(note.amountCents) || !money(note.paidCents) || note.paidCents > note.amountCents
        || !/^\d{4}-\d{2}-\d{2}$/.test(note.dueDate)) throw new BridgeError('invalid_source_data')
      notes.add(note.sourceId)
    }
  }
  if (ids.size) throw new BridgeError('invalid_source_data')
  return value
}
export function createBridgeHandler(deps: BridgeDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers })
    if (req.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    try {
      const authorization = req.headers.get('Authorization') ?? ''
      if (!/^Bearer \S+$/i.test(authorization)) return reply({ error: 'authentication_required' }, 401)
      const actor = await deps.authenticate(authorization)
      if (!actor) return reply({ error: 'authentication_required' }, 401)
      const body = await boundedJson(req, 8192)
      if (!body || typeof body !== 'object' || Array.isArray(body)
        || Object.keys(body).some(key => !['action', 'customerId', 'planIds', 'query', 'after'].includes(key))) return reply({ error: 'invalid_request' }, 400)
      if (body.action === 'search') {
        if (!actor.canManage) return reply({ error: 'finance_forbidden' }, 403)
        if (typeof body.query !== 'string' || body.query.length > 80 || typeof body.after !== 'string'
          || (body.after && !uuid.test(body.after))) return reply({ error: 'invalid_request' }, 400)
        return reply(await deps.source({ action: 'search', query: body.query, after: body.after }))
      }
      if (!['sync', 'link', 'unlink'].includes(body.action) || typeof body.customerId !== 'string' || !uuid.test(body.customerId)) return reply({ error: 'invalid_request' }, 400)
      const relink = body.action !== 'sync'
      if (relink && !actor.canManage) return reply({ error: 'finance_forbidden' }, 403)
      const context = await deps.context(body.customerId) // RLS checks ownership AND contract approval.
      if (!relink && !context) return reply({ connected: false })
      if (!relink && context?.importedAt && Date.now() - Date.parse(context.importedAt) < 30_000) return reply({ connected: true, cached: true })
      const planIds = body.action === 'unlink' ? [] : relink ? body.planIds : context!.planIds
      if (!Array.isArray(planIds) || planIds.length > 10 || (body.action !== 'unlink' && !planIds.length)
        || !planIds.every(id => typeof id === 'string' && uuid.test(id)) || new Set(planIds).size !== planIds.length) return reply({ error: 'invalid_request' }, 400)
      const snapshot = planIds.length ? validateSnapshot(await deps.source({ action: 'snapshot', planIds }), planIds) : null
      return reply(await deps.apply({ actorId: actor.id, customerId: body.customerId, planIds, version: context?.version ?? null, snapshot, relink }))
    } catch (error) {
      if (error instanceof BridgeError) return reply({ error: error.code }, error.status)
      if (error instanceof SyntaxError) return reply({ error: 'invalid_request' }, 400)
      return reply({ error: 'finance_source_unavailable' }, 503)
    }
  }
}
