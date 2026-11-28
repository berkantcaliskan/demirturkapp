RESET ROLE;
SELECT set_config('test.finance.plan','f1000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.finance.snapshot',jsonb_build_object(
 'schemaVersion',1,'currency','TRY','source','e-demirturk','asOf',now(),
 'contracts',jsonb_build_array(jsonb_build_object('sourceId',current_setting('test.finance.plan'),'totalCents',10000,'paidCents',2500,'remainingCents',7500,
  'notes',jsonb_build_array(jsonb_build_object('sourceId','1','number',1,'amountCents',10000,'paidCents',2500,'dueDate','2027-12-31','paidDate',NULL)),
  'payments','[]'::jsonb)))::text,false);

DO $$ BEGIN
 IF has_function_privilege('authenticated','public.portal_crm_apply_finance(uuid,uuid,uuid[],uuid,jsonb,boolean)','EXECUTE')
 OR has_function_privilege('anon','public.portal_crm_finance_context(uuid)','EXECUTE')
 OR has_function_privilege('authenticated','public.portal_crm_sync_candidates()','EXECUTE')
 OR has_table_privilege('authenticated','public.crm_finance_links','INSERT') THEN RAISE EXCEPTION 'Finance API privileges are too broad'; END IF;
END $$;
SET ROLE service_role;
SELECT public.portal_crm_apply_finance('10000000-0000-0000-0000-000000000005',current_setting('audit.customer_one')::uuid,
 ARRAY[current_setting('test.finance.plan')::uuid],NULL,current_setting('test.finance.snapshot')::jsonb,true);
RESET ROLE;
SELECT set_config('test.finance.version',(SELECT version::text FROM public.crm_finance_links WHERE customer_id=current_setting('audit.customer_one')::uuid),false);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.customer_finance_snapshots)<>1 OR (SELECT count(*) FROM public.promissory_notes)<>1
 OR (SELECT crm_paid_amount FROM public.promissory_notes)<>25 THEN RAISE EXCEPTION 'Own finance read or canonical note filtering failed'; END IF;
 IF public.portal_crm_finance_context(current_setting('audit.customer_one')::uuid)->>'version'<>current_setting('test.finance.version') THEN RAISE EXCEPTION 'Finance context mismatch'; END IF;
END $$;
SELECT set_config('test.finance.note',(SELECT id::text FROM public.promissory_notes WHERE crm_plan_id=current_setting('test.finance.plan')::uuid),false);
INSERT INTO storage.objects(bucket_id,name) VALUES('payment-receipts',current_setting('audit.customer_one')||'/crm-receipt.pdf');
INSERT INTO public.payment_submissions(note_id,customer_id,receipt_object_path,payment_method)
VALUES(current_setting('test.finance.note')::uuid,current_setting('audit.customer_one')::uuid,current_setting('audit.customer_one')||'/crm-receipt.pdf','bank_transfer');
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.customer_finance_snapshots) OR EXISTS(SELECT 1 FROM public.crm_finance_links)
 OR EXISTS(SELECT 1 FROM public.promissory_notes WHERE crm_plan_id IS NOT NULL) THEN RAISE EXCEPTION 'Finance leaked across customers'; END IF;
 BEGIN PERFORM public.portal_crm_finance_context(current_setting('audit.customer_one')::uuid); RAISE EXCEPTION 'Foreign customer accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',false);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.customer_finance_snapshots) OR EXISTS(SELECT 1 FROM public.crm_finance_links)
 THEN RAISE EXCEPTION 'Advisor received restricted financial data'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',false);
DO $$ BEGIN
 BEGIN UPDATE public.promissory_notes SET status='paid' WHERE crm_plan_id=current_setting('test.finance.plan')::uuid;
 RAISE EXCEPTION 'Client could mark CRM note paid'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- Repeated imports are idempotent. A late response cannot replace newer source data.
SET ROLE service_role;
SELECT public.portal_crm_apply_finance(NULL,current_setting('audit.customer_one')::uuid,
 ARRAY[current_setting('test.finance.plan')::uuid],current_setting('test.finance.version')::uuid,current_setting('test.finance.snapshot')::jsonb,false);
RESET ROLE;
DO $$ BEGIN
 IF (SELECT status FROM public.promissory_notes WHERE id=current_setting('test.finance.note')::uuid)<>'verifying'
 THEN RAISE EXCEPTION 'CRM refresh lost a pending receipt review'; END IF;
END $$;
SET ROLE service_role;
DO $$ DECLARE result jsonb; BEGIN
 result:=public.portal_crm_apply_finance(NULL,current_setting('audit.customer_one')::uuid,
  ARRAY[current_setting('test.finance.plan')::uuid],current_setting('test.finance.version')::uuid,
  jsonb_set(current_setting('test.finance.snapshot')::jsonb,'{asOf}',to_jsonb(now()-interval '1 hour')),false);
 IF result->>'staleIgnored'<>'true' THEN RAISE EXCEPTION 'Late response was accepted'; END IF;
 BEGIN PERFORM public.portal_crm_apply_finance('10000000-0000-0000-0000-000000000005',current_setting('audit.customer_two')::uuid,
  ARRAY[current_setting('test.finance.plan')::uuid],NULL,current_setting('test.finance.snapshot')::jsonb,true);
 RAISE EXCEPTION 'Same CRM contract linked to another customer'; EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT count(*) FROM public.promissory_notes WHERE crm_plan_id=current_setting('test.finance.plan')::uuid)<>1 THEN RAISE EXCEPTION 'Repeated import duplicated a note'; END IF;
END $$;

-- A mapping change invalidates in-flight snapshots and does not reassign a historical contract.
SET ROLE service_role;
SELECT public.portal_crm_apply_finance('10000000-0000-0000-0000-000000000005',current_setting('audit.customer_one')::uuid,
 ARRAY[current_setting('test.finance.plan')::uuid],NULL,current_setting('test.finance.snapshot')::jsonb,true);
DO $$ BEGIN
 BEGIN PERFORM public.portal_crm_apply_finance(NULL,current_setting('audit.customer_one')::uuid,
  ARRAY[current_setting('test.finance.plan')::uuid],current_setting('test.finance.version')::uuid,current_setting('test.finance.snapshot')::jsonb,false);
 RAISE EXCEPTION 'Old mapping version was accepted'; EXCEPTION WHEN serialization_failure THEN NULL; END;
END $$;
SELECT public.portal_crm_apply_finance('10000000-0000-0000-0000-000000000005',current_setting('audit.customer_one')::uuid,ARRAY[]::uuid[],NULL,NULL,true);
DO $$ BEGIN
 BEGIN PERFORM public.portal_crm_apply_finance('10000000-0000-0000-0000-000000000005',current_setting('audit.customer_two')::uuid,
  ARRAY[current_setting('test.finance.plan')::uuid],NULL,current_setting('test.finance.snapshot')::jsonb,true);
 RAISE EXCEPTION 'Historical CRM contract was reassigned'; EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.promissory_notes WHERE crm_plan_id=current_setting('test.finance.plan')::uuid AND crm_archived)
 OR EXISTS(SELECT 1 FROM public.customer_finance_snapshots) THEN RAISE EXCEPTION 'Unlink did not preserve historical notes'; END IF;
END $$;
