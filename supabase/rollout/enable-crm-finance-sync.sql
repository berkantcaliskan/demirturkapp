-- Run only after both finance endpoints, migrations and server secrets are installed.
-- In Supabase Vault, create crm_finance_worker_url and crm_finance_worker_secret.
-- The worker URL must be this project's /functions/v1/crm-finance-worker endpoint.
-- The worker secret must match CRM_FINANCE_WORKER_SECRET; never use the CRM bridge key here.
-- This file is deliberately outside migrations: installing code does not start production jobs.
DO $$
DECLARE job bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM vault.decrypted_secrets WHERE name='crm_finance_worker_url')
 OR NOT EXISTS(SELECT 1 FROM vault.decrypted_secrets WHERE name='crm_finance_worker_secret')
 THEN RAISE EXCEPTION 'CRM finance worker Vault configuration is required'; END IF;
 SELECT jobid INTO job FROM cron.job WHERE jobname='crm-finance-sync';
 IF job IS NOT NULL THEN PERFORM cron.unschedule(job); END IF;
 PERFORM cron.schedule('crm-finance-sync','* * * * *',$job$
  SELECT net.http_post(
   url:=(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='crm_finance_worker_url' LIMIT 1),
   headers:=jsonb_build_object('Content-Type','application/json','x-cron-key',(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='crm_finance_worker_secret' LIMIT 1)),
   body:='{}'::jsonb,timeout_milliseconds:=60000
  );
 $job$);
END $$;
