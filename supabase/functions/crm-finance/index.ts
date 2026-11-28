import { createClient } from 'npm:@supabase/supabase-js@2.119.2'
import { BridgeError, createBridgeHandler } from './handler.ts'
import { requestCrmFinance } from './source.ts'

const url = Deno.env.get('SUPABASE_URL')!, serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })
Deno.serve(async req => {
  // Request-scoped client: one customer's JWT can never leak into another request.
  const client = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  return createBridgeHandler({
    authenticate: async authorization => {
      const { data: { user }, error } = await client.auth.getUser(authorization.slice(7))
      if (error || !user) return null
      const { data: profile } = await client.from('profiles').select('role,staff_role').eq('id', user.id).single()
      if (!profile) return null
      return { id: user.id, canManage: profile.role === 'admin' || ['management', 'accounting'].includes(profile.staff_role) }
    },
    context: async customerId => {
      const { data, error } = await client.rpc('portal_crm_finance_context', { p_customer_id: customerId })
      if (error) throw new BridgeError(error.code === '42501' ? 'finance_forbidden' : 'finance_setup_pending', error.code === '42501' ? 403 : 503)
      return data
    },
    source: async body => {
      const endpoint = Deno.env.get('CRM_FINANCE_EXPORT_URL') ?? '', secret = Deno.env.get('CRM_MOBILE_BRIDGE_KEY') ?? ''
      return requestCrmFinance(body, endpoint, secret)
    },
    apply: async args => {
      const { data, error } = await admin.rpc('portal_crm_apply_finance', {
        p_actor: args.actorId, p_customer_id: args.customerId, p_plan_ids: args.planIds,
        p_expected_version: args.version, p_snapshot: args.snapshot, p_relink: args.relink,
      })
      if (error) {
        if (error.code === '23505') throw new BridgeError('finance_plan_already_linked', 409)
        if (error.code === '40001') throw new BridgeError('finance_link_changed', 409)
        throw new BridgeError('finance_import_failed')
      }
      return data
    },
  })(req)
})
