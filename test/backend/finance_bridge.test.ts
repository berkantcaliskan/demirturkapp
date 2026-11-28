import { test } from 'node:test'
import assert from 'node:assert/strict'
import { BridgeError, createBridgeHandler, type BridgeDependencies } from '../../supabase/functions/crm-finance/handler.ts'
const customerId = 'a1000000-0000-0000-0000-000000000001'
const planId = 'b1000000-0000-0000-0000-000000000001'
const snapshot = () => ({ schemaVersion: 1, source: 'e-demirturk', currency: 'TRY', asOf: '2026-11-27T12:00:00Z', contracts: [
  { sourceId: planId, totalCents: 10000, paidCents: 2500, remainingCents: 7500,
    notes: [{ sourceId: '1', number: 1, amountCents: 10000, paidCents: 2500, dueDate: '2026-12-31' }], payments: [] },
] })
const request = (body: unknown, token = 'user-token') => new Request('https://example.invalid', {
  method: 'POST', headers: token ? { Authorization: 'Bearer ' + token } : {}, body: JSON.stringify(body),
})
function setup(overrides: Partial<BridgeDependencies> = {}) {
  const writes: any[] = [], sourceReads: any[] = []
  const deps: BridgeDependencies = {
    authenticate: async () => ({ id: 'actor', canManage: false }),
    context: async () => ({ planIds: [planId], version: 'version' }),
    source: async body => { sourceReads.push(body); return snapshot() },
    apply: async body => { writes.push(body); return { connected: true } }, ...overrides,
  }
  return { handler: createBridgeHandler(deps), writes, sourceReads }
}
test('Unauthenticated requests cannot query CRM or import data', async () => {
  const { handler, writes, sourceReads } = setup()
  assert.equal((await handler(request({ action: 'sync', customerId }, ''))).status, 401)
  assert.equal(writes.length + sourceReads.length, 0)
})
test('Customers cannot search or link another financial record', async () => {
  const { handler, writes, sourceReads } = setup()
  for (const action of ['search', 'link', 'unlink']) assert.equal((await handler(request({ action, customerId, query: '', after: '', planIds: [planId] }))).status, 403)
  assert.equal(writes.length + sourceReads.length, 0)
})
test('Ownership failure stops before reading CRM', async () => {
  const { handler, sourceReads } = setup({ context: async () => { throw new BridgeError('finance_forbidden', 403) } })
  assert.equal((await handler(request({ action: 'sync', customerId }))).status, 403)
  assert.equal(sourceReads.length, 0)
})
test('Client plan IDs cannot override the approved server mapping during sync', async () => {
  const { handler, sourceReads, writes } = setup()
  assert.equal((await handler(request({ action: 'sync', customerId, planIds: ['forged'] }))).status, 200)
  assert.deepEqual(sourceReads[0].planIds, [planId])
  assert.equal(writes[0].version, 'version')
})
test('Network and reconciliation errors leave previous snapshots untouched', async () => {
  for (const failure of [new Error('network'), new BridgeError('finance_reconciliation_required', 409)]) {
    const { handler, writes } = setup({ source: async () => { throw failure } })
    assert.ok((await handler(request({ action: 'sync', customerId }))).status >= 400)
    assert.equal(writes.length, 0)
  }
})
test('Malformed upstream balances cannot reach the import RPC', async () => {
  const bad = snapshot(); bad.contracts[0].remainingCents = 1
  const { handler, writes } = setup({ source: async () => bad })
  assert.equal((await handler(request({ action: 'sync', customerId }))).status, 503)
  assert.equal(writes.length, 0)
})
test('Recent cached data avoids duplicate CRM requests', async () => {
  const { handler, sourceReads, writes } = setup({ context: async () => ({ planIds: [planId], version: 'version', importedAt: new Date().toISOString() }) })
  assert.equal((await handler(request({ action: 'sync', customerId }))).status, 200)
  assert.equal(writes.length + sourceReads.length, 0)
})
test('Staff linking imports only after validating the complete source snapshot', async () => {
  const { handler, writes } = setup({ authenticate: async () => ({ id: 'manager', canManage: true }), context: async () => null })
  assert.equal((await handler(request({ action: 'link', customerId, planIds: [planId] }))).status, 200)
  assert.equal(writes[0].actorId, 'manager')
  assert.equal(writes[0].relink, true)
})
test('Extra payload fields and oversized requests are rejected', async () => {
  const { handler, writes } = setup()
  assert.equal((await handler(request({ action: 'sync', customerId, snapshot: snapshot() }))).status, 400)
  assert.equal((await handler(request({ action: 'sync', customerId, query: 'x'.repeat(9000) }))).status, 413)
  assert.equal(writes.length, 0)
})
