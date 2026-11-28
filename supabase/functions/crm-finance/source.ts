import { boundedJson, BridgeError } from './handler.ts'
export async function requestCrmFinance(body: Record<string, unknown>, endpoint: string, secret: string) {
  if (!/^https:\/\/[a-z0-9]+\.supabase\.co\/functions\/v1\/mobile-finance-export$/.test(endpoint) || secret.length < 32) throw new BridgeError('finance_setup_pending')
  const response = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json', 'x-demirturk-bridge-key': secret }, body: JSON.stringify(body), signal: AbortSignal.timeout(12_000), redirect: 'error' })
  const result = await boundedJson(response, 2_000_000)
  if (!response.ok) {
    const code = ['finance_reconciliation_required', 'finance_unbalanced_plan', 'finance_overpayment'].includes(result?.error) ? result.error : 'finance_source_unavailable'
    throw new BridgeError(code, response.status === 409 ? 409 : 503)
  }
  return result
}
