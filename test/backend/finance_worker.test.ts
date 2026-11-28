import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createFinanceWorker } from '../../supabase/functions/crm-finance-worker/handler.ts'
test('The scheduler cannot read customer candidates without its dedicated secret', async () => {
  let claims = 0
  const handler = createFinanceWorker({ secret: 'a'.repeat(40), claim: async () => { claims++; return [] }, sync: async () => {} })
  const response = await handler(new Request('https://example.invalid', { method: 'POST' }))
  assert.equal(response.status, 401); assert.equal(claims, 0)
})
test('Failed customers do not block the batch; concurrency and response privacy are bounded', async () => {
  let active = 0, maximum = 0
  const secret = 'a'.repeat(40)
  const handler = createFinanceWorker({ secret,
    claim: async () => Array.from({ length: 12 }, (_, i) => ({ customer_id: `private-id-${i}`, plan_ids: [], version: 'v' })),
    sync: async candidate => {
      active++; maximum = Math.max(maximum, active)
      await new Promise(resolve => setTimeout(resolve, 1))
      active--
      if (candidate.customer_id.endsWith('-1')) throw Error('private-upstream-error')
    },
  })
  const response = await handler(new Request('https://example.invalid', { method: 'POST', headers: { 'x-cron-key': secret } }))
  assert.equal(response.status, 207)
  assert.deepEqual(await response.json(), { completed: 11, failed: 1 })
  assert.ok(maximum <= 5)
})
