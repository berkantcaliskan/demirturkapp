BEGIN;
CREATE SCHEMA IF NOT EXISTS portal_private;
REVOKE ALL ON SCHEMA portal_private FROM PUBLIC,anon,authenticated;

CREATE TABLE public.crm_finance_links (
 customer_id uuid PRIMARY KEY REFERENCES public.customers(id) ON DELETE RESTRICT,
 plan_ids uuid[] NOT NULL CHECK(cardinality(plan_ids) BETWEEN 1 AND 10),
 version uuid NOT NULL DEFAULT gen_random_uuid(),
 linked_by uuid NOT NULL REFERENCES public.profiles(id),linked_at timestamptz NOT NULL DEFAULT now(),last_attempt_at timestamptz
);
CREATE TABLE public.customer_finance_snapshots (
 customer_id uuid PRIMARY KEY REFERENCES public.customers(id) ON DELETE RESTRICT,
 snapshot jsonb NOT NULL CHECK(jsonb_typeof(snapshot)='object'),
 source_at timestamptz NOT NULL,imported_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE portal_private.crm_plan_owners (
 plan_id uuid PRIMARY KEY,customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT
);
CREATE INDEX crm_plan_owner_customer ON portal_private.crm_plan_owners(customer_id);
CREATE TABLE portal_private.crm_finance_link_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,actor_id uuid NOT NULL REFERENCES public.profiles(id),
 customer_id uuid NOT NULL REFERENCES public.customers(id),plan_ids uuid[] NOT NULL,created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.crm_finance_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_finance_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE portal_private.crm_plan_owners ENABLE ROW LEVEL SECURITY;
ALTER TABLE portal_private.crm_finance_link_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crm_finance_links,public.customer_finance_snapshots,
 portal_private.crm_plan_owners,portal_private.crm_finance_link_audit FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.crm_finance_links,public.customer_finance_snapshots TO authenticated;
CREATE POLICY crm_links_read ON public.crm_finance_links FOR SELECT TO authenticated USING (
 (SELECT public.can_manage_finance()) OR EXISTS (SELECT 1 FROM public.customers c WHERE c.id=customer_id AND c.auth_user_id=(SELECT auth.uid()) AND c.contract_status='approved')
);
CREATE POLICY crm_snapshots_read ON public.customer_finance_snapshots FOR SELECT TO authenticated USING (
 (SELECT public.can_manage_finance()) OR EXISTS (SELECT 1 FROM public.customers c WHERE c.id=customer_id AND c.auth_user_id=(SELECT auth.uid()) AND c.contract_status='approved')
);

ALTER TABLE public.promissory_notes
 ADD COLUMN crm_plan_id uuid, ADD COLUMN crm_note_id text,
 ADD COLUMN crm_paid_amount numeric(14,2),ADD COLUMN crm_archived boolean NOT NULL DEFAULT false,
 ADD CONSTRAINT crm_note_identity UNIQUE(crm_plan_id,crm_note_id),
 ADD CONSTRAINT crm_note_payment CHECK(crm_paid_amount IS NULL OR (crm_paid_amount>=0 AND crm_paid_amount<=amount));

CREATE FUNCTION public.portal_crm_finance_context(p_customer_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT ((SELECT public.can_manage_finance()) OR EXISTS(
  SELECT 1 FROM public.customers c WHERE c.id=p_customer_id AND c.auth_user_id=(SELECT auth.uid()) AND c.contract_status='approved'))
 THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('planIds',l.plan_ids,'version',l.version,'importedAt',s.imported_at) INTO result
 FROM public.crm_finance_links l LEFT JOIN public.customer_finance_snapshots s ON s.customer_id=l.customer_id WHERE l.customer_id=p_customer_id;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.portal_crm_finance_context(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.portal_crm_finance_context(uuid) TO authenticated;

-- The only public wrapper for privileged import is executable by service_role alone.
CREATE FUNCTION public.portal_crm_apply_finance(
 p_actor uuid,p_customer_id uuid,p_plan_ids uuid[],p_expected_version uuid,p_snapshot jsonb,p_relink boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE link public.crm_finance_links%ROWTYPE; customer public.customers%ROWTYPE;
 actor public.profiles%ROWTYPE; contract jsonb; note jsonb; source_time timestamptz;
 import_time timestamptz:=now(); allowed boolean; seen uuid[]:='{}'; note_count integer;
BEGIN
 SELECT * INTO actor FROM public.profiles WHERE id=p_actor;
 SELECT * INTO customer FROM public.customers WHERE id=p_customer_id FOR UPDATE;
 IF customer.id IS NULL OR (p_actor IS NOT NULL AND actor.id IS NULL) OR (p_actor IS NULL AND p_relink)
 THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501'; END IF;
 allowed:=p_actor IS NULL OR actor.role='admin' OR actor.staff_role IN ('accounting','management');
 IF p_relink AND NOT coalesce(allowed,false) THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501'; END IF;
 IF NOT coalesce(allowed,false) AND (customer.auth_user_id IS DISTINCT FROM p_actor OR customer.contract_status<>'approved')
 THEN RAISE EXCEPTION 'finance_forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO link FROM public.crm_finance_links WHERE customer_id=p_customer_id FOR UPDATE;
 IF NOT p_relink AND (link.customer_id IS NULL OR link.version IS DISTINCT FROM p_expected_version OR link.plan_ids IS DISTINCT FROM p_plan_ids)
 THEN RAISE EXCEPTION 'finance_link_changed' USING ERRCODE='40001'; END IF;
 IF p_plan_ids IS NULL OR cardinality(p_plan_ids)>10 OR array_position(p_plan_ids,NULL) IS NOT NULL
 OR cardinality(p_plan_ids)<>(SELECT count(DISTINCT id) FROM unnest(p_plan_ids) id) THEN RAISE EXCEPTION 'finance_invalid_data'; END IF;

 IF cardinality(p_plan_ids)=0 THEN
  IF NOT p_relink THEN RAISE EXCEPTION 'finance_invalid_data'; END IF;
  PERFORM set_config('portal.crm_finance_sync','on',true);
  UPDATE public.promissory_notes SET crm_archived=true WHERE customer_id=p_customer_id AND crm_plan_id IS NOT NULL;
  PERFORM set_config('portal.crm_finance_sync','off',true);
  -- Keep original ownership after unlinking so an old contract cannot be exposed to a second account.
  DELETE FROM public.customer_finance_snapshots WHERE customer_id=p_customer_id;
  DELETE FROM public.crm_finance_links WHERE customer_id=p_customer_id;
  INSERT INTO portal_private.crm_finance_link_audit(actor_id,customer_id,plan_ids) VALUES(p_actor,p_customer_id,p_plan_ids);
  RETURN jsonb_build_object('connected',false);
 END IF;
 IF p_snapshot IS NULL OR p_snapshot->>'schemaVersion'<>'1' OR p_snapshot->>'currency'<>'TRY'
 OR p_snapshot->>'source'<>'e-demirturk' OR jsonb_typeof(p_snapshot->'contracts') IS DISTINCT FROM 'array'
 OR jsonb_array_length(p_snapshot->'contracts')<>cardinality(p_plan_ids) OR octet_length(p_snapshot::text)>2000000
 THEN RAISE EXCEPTION 'finance_invalid_data'; END IF;
 source_time:=(p_snapshot->>'asOf')::timestamptz;
 IF source_time IS NULL OR source_time>now()+interval '5 minutes' THEN RAISE EXCEPTION 'finance_invalid_data'; END IF;
 IF NOT p_relink AND EXISTS(SELECT 1 FROM public.customer_finance_snapshots s WHERE s.customer_id=p_customer_id AND s.source_at>source_time)
 THEN RETURN jsonb_build_object('connected',true,'staleIgnored',true); END IF;

 FOR contract IN SELECT value FROM jsonb_array_elements(p_snapshot->'contracts') LOOP
  IF NOT ((contract->>'sourceId')::uuid=ANY(p_plan_ids)) OR (contract->>'sourceId')::uuid=ANY(seen)
   OR (contract->>'totalCents')::numeric<>(contract->>'paidCents')::numeric+(contract->>'remainingCents')::numeric
   OR (contract->>'paidCents')::numeric<0 OR (contract->>'remainingCents')::numeric<0
   OR jsonb_typeof(contract->'notes') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'finance_invalid_data'; END IF;
  seen:=array_append(seen,(contract->>'sourceId')::uuid);
 END LOOP;
 IF p_relink THEN
  IF EXISTS(SELECT 1 FROM portal_private.crm_plan_owners WHERE plan_id=ANY(p_plan_ids) AND customer_id<>p_customer_id)
  THEN RAISE EXCEPTION 'finance_plan_already_linked' USING ERRCODE='23505'; END IF;
  INSERT INTO portal_private.crm_plan_owners(plan_id,customer_id) SELECT id,p_customer_id FROM unnest(p_plan_ids) id ON CONFLICT(plan_id) DO NOTHING;
  INSERT INTO public.crm_finance_links(customer_id,plan_ids,linked_by) VALUES(p_customer_id,p_plan_ids,p_actor)
   ON CONFLICT(customer_id) DO UPDATE SET plan_ids=excluded.plan_ids,linked_by=p_actor,linked_at=now(),version=gen_random_uuid();
  INSERT INTO portal_private.crm_finance_link_audit(actor_id,customer_id,plan_ids) VALUES(p_actor,p_customer_id,p_plan_ids);
 END IF;
 PERFORM set_config('portal.crm_finance_sync','on',true);
 UPDATE public.promissory_notes SET crm_archived=true WHERE customer_id=p_customer_id AND crm_plan_id IS NOT NULL;
 FOR contract IN SELECT value FROM jsonb_array_elements(p_snapshot->'contracts') LOOP
  note_count:=jsonb_array_length(contract->'notes');
  IF note_count NOT BETWEEN 1 AND 360 THEN RAISE EXCEPTION 'finance_invalid_data'; END IF;
  FOR note IN SELECT value FROM jsonb_array_elements(contract->'notes') LOOP
   IF (note->>'amountCents')::numeric<=0 OR (note->>'amountCents')::numeric<>trunc((note->>'amountCents')::numeric)
    OR (note->>'paidCents')::numeric<>trunc((note->>'paidCents')::numeric) OR coalesce(length(note->>'sourceId'),0) NOT BETWEEN 1 AND 100
    THEN RAISE EXCEPTION 'finance_invalid_data'; END IF;
   INSERT INTO public.promissory_notes(customer_id,note_number,installment_index,total_installments,amount,due_date,paid_at,status,description,crm_plan_id,crm_note_id,crm_paid_amount,crm_archived)
   VALUES(p_customer_id,'CRM-'||(contract->>'sourceId')||'-'||(note->>'sourceId'),(note->>'number')::int,note_count,
    (note->>'amountCents')::numeric/100,(note->>'dueDate')::date,
    CASE WHEN (note->>'paidCents')::numeric=(note->>'amountCents')::numeric THEN nullif(note->>'paidDate','')::date::timestamptz END,
    CASE WHEN (note->>'paidCents')::numeric=(note->>'amountCents')::numeric THEN 'paid'::public.note_status
     WHEN (note->>'dueDate')::date<(now() AT TIME ZONE 'Europe/Istanbul')::date THEN 'overdue'::public.note_status ELSE 'pending'::public.note_status END,
    'e-Demirtürk · Senet '||(note->>'number')||'/'||note_count,(contract->>'sourceId')::uuid,note->>'sourceId',(note->>'paidCents')::numeric/100,false)
   ON CONFLICT(crm_plan_id,crm_note_id) DO UPDATE SET
    installment_index=excluded.installment_index,total_installments=excluded.total_installments,amount=excluded.amount,
    due_date=excluded.due_date,paid_at=excluded.paid_at,
    status=CASE WHEN excluded.status<>'paid' AND EXISTS(SELECT 1 FROM public.payment_submissions ps WHERE ps.note_id=public.promissory_notes.id AND ps.status='submitted')
     THEN 'verifying'::public.note_status ELSE excluded.status END,
    crm_paid_amount=excluded.crm_paid_amount,crm_archived=false
   WHERE public.promissory_notes.customer_id=p_customer_id;
  END LOOP;
 END LOOP;
 PERFORM set_config('portal.crm_finance_sync','off',true);
 INSERT INTO public.customer_finance_snapshots(customer_id,snapshot,source_at,imported_at) VALUES(p_customer_id,p_snapshot,source_time,import_time)
 ON CONFLICT(customer_id) DO UPDATE SET snapshot=excluded.snapshot,source_at=excluded.source_at,imported_at=excluded.imported_at;
 RETURN jsonb_build_object('connected',true,'importedAt',import_time);
END $$;
REVOKE ALL ON FUNCTION public.portal_crm_apply_finance(uuid,uuid,uuid[],uuid,jsonb,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.portal_crm_apply_finance(uuid,uuid,uuid[],uuid,jsonb,boolean) TO service_role;

CREATE FUNCTION portal_private.note_is_visible(p_customer uuid,p_plan uuid,p_archived boolean) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND public.can_access_customer(p_customer) AND NOT p_archived AND CASE WHEN p_plan IS NULL THEN NOT EXISTS(SELECT 1 FROM public.crm_finance_links WHERE customer_id=p_customer)
 ELSE EXISTS(SELECT 1 FROM public.crm_finance_links WHERE customer_id=p_customer AND p_plan=ANY(plan_ids)) END;
$$;
-- The helper only returns a boolean for an already RLS-filtered note, never a customer directory.
GRANT USAGE ON SCHEMA portal_private TO authenticated;
REVOKE ALL ON FUNCTION portal_private.note_is_visible(uuid,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION portal_private.note_is_visible(uuid,uuid,boolean) TO authenticated;
CREATE POLICY crm_canonical_notes ON public.promissory_notes AS RESTRICTIVE FOR SELECT TO authenticated
 USING(portal_private.note_is_visible(customer_id,crm_plan_id,crm_archived));

CREATE FUNCTION portal_private.guard_crm_note_write() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF current_setting('portal.crm_finance_sync',true)='on' AND current_user='postgres' THEN RETURN NEW; END IF;
 IF (TG_OP='DELETE' AND OLD.crm_plan_id IS NOT NULL) OR (TG_OP<>'DELETE' AND NEW.crm_plan_id IS NOT NULL) THEN
  IF TG_OP='UPDATE' AND OLD.status<>'paid' AND NEW.status<>'paid'
   AND (to_jsonb(NEW)-ARRAY['status','payment_method'])=(to_jsonb(OLD)-ARRAY['status','payment_method']) THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'CRM tahsilatını e-Demirtürk üzerinden güncelleyin.' USING ERRCODE='42501';
 END IF;
 IF TG_OP<>'DELETE' AND EXISTS(SELECT 1 FROM public.crm_finance_links WHERE customer_id=NEW.customer_id)
 THEN RAISE EXCEPTION 'CRM ödeme planı e-Demirtürk tarafından yönetiliyor.' USING ERRCODE='42501'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION portal_private.guard_crm_note_write() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_crm_note_write BEFORE INSERT OR UPDATE OR DELETE ON public.promissory_notes FOR EACH ROW EXECUTE FUNCTION portal_private.guard_crm_note_write();

CREATE FUNCTION public.portal_crm_sync_candidates() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 WITH candidates AS (
  SELECT l.customer_id FROM public.crm_finance_links l LEFT JOIN public.customer_finance_snapshots s ON s.customer_id=l.customer_id
  WHERE (l.last_attempt_at IS NULL OR l.last_attempt_at<now()-interval '45 seconds')
   AND (s.imported_at IS NULL OR s.imported_at<now()-interval '45 seconds')
  ORDER BY l.last_attempt_at NULLS FIRST,l.customer_id LIMIT 20 FOR UPDATE OF l SKIP LOCKED
 ), claimed AS (
  UPDATE public.crm_finance_links l SET last_attempt_at=now() FROM candidates c WHERE l.customer_id=c.customer_id
  RETURNING l.customer_id,l.plan_ids,l.version
 ) SELECT coalesce(jsonb_agg(to_jsonb(claimed)),'[]') INTO result FROM claimed;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.portal_crm_sync_candidates() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.portal_crm_sync_candidates() TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
