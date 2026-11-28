import { createClient } from 'npm:@supabase/supabase-js@2.119.2'
import { validateSnapshot } from '../crm-finance/handler.ts'
import { requestCrmFinance } from '../crm-finance/source.ts'
import { createFinanceWorker } from './handler.ts'
const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false, autoRefreshToken: false } })
Deno.serve(createFinanceWorker({
  secret: Deno.env.get('CRM_FINANCE_WORKER_SECRET') ?? '',
  claim: async () => {
    const { data, error } = await admin.rpc('portal_crm_sync_candidates')
    if (error) throw Error('claim_failed')
    return data
  },
  sync: async candidate => {
    const source = await requestCrmFinance({ action: 'snapshot', planIds: candidate.plan_ids }, Deno.env.get('CRM_FINANCE_EXPORT_URL') ?? '', Deno.env.get('CRM_MOBILE_BRIDGE_KEY') ?? '')
    const snapshot = validateSnapshot(source, candidate.plan_ids)
    const { error } = await admin.rpc('portal_crm_apply_finance', {
      p_actor: null, p_customer_id: candidate.customer_id, p_plan_ids: candidate.plan_ids,
      p_expected_version: candidate.version, p_snapshot: snapshot, p_relink: false,
    })
    if (error) throw Error('sync_failed')
  },
}))
