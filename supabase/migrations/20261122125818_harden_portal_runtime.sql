create schema if not exists portal_private;
revoke all on schema portal_private from public, anon, authenticated;

-- Auth Admin API markers cannot be supplied through public signup metadata.
create function portal_private.validate_new_account()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(new.raw_app_meta_data->>'portal_registration','') not in ('customer_v1','staff_v1') then
    raise exception 'Use the application registration service' using errcode='42501';
  end if;
  return new;
end $$;
revoke all on function portal_private.validate_new_account() from public, anon, authenticated;
create trigger portal_validate_new_account before insert on auth.users
  for each row execute function portal_private.validate_new_account();

create function portal_private.validate_message_limits()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if char_length(btrim(new.body)) not between 1 and 4000 then
    raise exception 'Mesaj 1–4000 karakter olmalı.' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('message:'||new.sender_id::text,0));
  if (select count(*) from public.ticket_messages where sender_id=new.sender_id and created_at>now()-interval '1 minute') >= 40
    or (select count(*) from public.ticket_messages where sender_id=new.sender_id and created_at>now()-interval '1 day') >= 1000 then
    raise exception 'Mesaj sınırına ulaştınız. Biraz sonra tekrar deneyin.' using errcode='P0001';
  end if;
  return new;
end $$;
revoke all on function portal_private.validate_message_limits() from public, anon, authenticated;
create trigger portal_validate_message_limits before insert on public.ticket_messages
  for each row execute function portal_private.validate_message_limits();
create index if not exists ticket_messages_sender_time_idx on public.ticket_messages(sender_id,created_at desc);

create function portal_private.validate_upload_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
  maximum bigint;
  uploaded_bytes bigint;
  recent_uploads bigint;
  incoming_bytes bigint;
begin
  if actor is null or new.bucket_id not in ('payment-receipts','customer-contracts','message-attachments') then return new; end if;
  maximum := case new.bucket_id when 'payment-receipts' then 10485760 when 'customer-contracts' then 20971520 else 104857600 end;
  incoming_bytes := case when new.metadata->>'size' ~ '^[0-9]{1,12}$' then (new.metadata->>'size')::bigint else maximum end;
  if incoming_bytes>maximum then raise exception 'Dosya boyutu izin verilen sınırı aşıyor.'; end if;
  if new.bucket_id='message-attachments' and lower(new.name) !~ '\.(pdf|docx?|xlsx?|pptx?|jpe?g|png|webp|heic|mp4|mov|mp3|m4a|wav|txt|csv|zip)$' then
    raise exception 'Bu dosya türü desteklenmiyor.' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('upload:'||actor::text,0));
  select coalesce(sum(case when o.metadata->>'size' ~ '^[0-9]{1,12}$' then (o.metadata->>'size')::bigint
      else case o.bucket_id when 'payment-receipts' then 10485760 when 'customer-contracts' then 20971520 else 104857600 end end),0),
    count(*) filter(where o.created_at>now()-interval '1 hour')
    into uploaded_bytes,recent_uploads
  from storage.objects o where o.id<>new.id and (
    (o.bucket_id='message-attachments' and split_part(o.name,'/',2)=actor::text)
    or (o.bucket_id='customer-contracts' and split_part(o.name,'/',1)=actor::text)
    or (o.bucket_id='payment-receipts' and exists(select 1 from public.customers c where c.auth_user_id=actor and c.id::text=split_part(o.name,'/',1)))
  );
  if uploaded_bytes+incoming_bytes>524288000 then raise exception 'Hesabınızın dosya alanı sınırına ulaşıldı. Şirketle iletişime geçin.'; end if;
  if tg_op='INSERT' and recent_uploads>=20 then raise exception 'Yükleme sınırına ulaştınız. Biraz sonra tekrar deneyin.'; end if;
  return new;
end $$;
revoke all on function portal_private.validate_upload_quota() from public, anon, authenticated;
create trigger portal_validate_upload_quota before insert or update of metadata on storage.objects
  for each row execute function portal_private.validate_upload_quota();

-- The public wrapper validates the project; its internal helper is not a client API.
revoke execute on function public.create_contract_record(text,text,text,uuid,date,uuid,text,text,text) from public, anon, authenticated;

create function public.attach_pending_contract_document(p_contract_id uuid,p_storage_path text,p_file_name text,p_content_type text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_manage_finance() then raise exception 'Contract document access denied' using errcode='42501'; end if;
  if split_part(p_storage_path,'/',1) is distinct from (select auth.uid())::text
    or p_content_type not in ('application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    or lower(p_file_name) !~ '\.(pdf|docx?)$'
    or not exists(select 1 from storage.objects where bucket_id='customer-contracts' and name=p_storage_path) then
    raise exception 'Geçerli bir sözleşme dosyası yükleyin.' using errcode='22023';
  end if;
  perform 1 from public.pending_contract_records where id=p_contract_id for update;
  if not found then raise exception 'Bekleyen sözleşme bulunamadı.'; end if;
  update public.pending_contract_records set storage_path=p_storage_path,file_name=p_file_name,content_type=p_content_type,uploaded_by=(select auth.uid()) where id=p_contract_id;
end $$;
revoke all on function public.attach_pending_contract_document(uuid,text,text,text) from public,anon;
grant execute on function public.attach_pending_contract_document(uuid,text,text,text) to authenticated;

alter function public.link_pending_contract_account(uuid,uuid) set schema portal_private;
revoke all on function portal_private.link_pending_contract_account(uuid,uuid) from public,anon,authenticated;
create function public.link_pending_contract_account(p_pending_contract_id uuid,p_account_customer_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_manage_finance() then raise exception 'Contract approval denied' using errcode='42501'; end if;
  perform 1 from public.pending_contract_records where id=p_pending_contract_id for update;
  if not exists(select 1 from public.pending_contract_records p join storage.objects o on o.bucket_id='customer-contracts' and o.name=p.storage_path where p.id=p_pending_contract_id) then
    raise exception 'Onaylamadan önce sözleşme dosyasını ekleyin.' using errcode='22023';
  end if;
  return portal_private.link_pending_contract_account(p_pending_contract_id,p_account_customer_id);
end $$;
revoke all on function public.link_pending_contract_account(uuid,uuid) from public,anon;
grant execute on function public.link_pending_contract_account(uuid,uuid) to authenticated;

alter function public.link_customer_account(uuid,uuid) set schema portal_private;
revoke all on function portal_private.link_customer_account(uuid,uuid) from public,anon,authenticated;
create function public.link_customer_account(p_contract_customer_id uuid,p_account_customer_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_manage_finance() then raise exception 'Contract approval denied' using errcode='42501'; end if;
  perform 1 from public.customers where id=p_contract_customer_id for update;
  if not exists(select 1 from public.customer_contract_documents d join storage.objects o on o.bucket_id='customer-contracts' and o.name=d.storage_path where d.customer_id=p_contract_customer_id) then
    raise exception 'Onaylamadan önce sözleşme dosyasını ekleyin.' using errcode='22023';
  end if;
  return portal_private.link_customer_account(p_contract_customer_id,p_account_customer_id);
end $$;
revoke all on function public.link_customer_account(uuid,uuid) from public,anon;
grant execute on function public.link_customer_account(uuid,uuid) to authenticated;

-- Add missing FK indexes without changing visibility or deleting existing indexes.
do $$ declare fk record; columns_sql text; begin
  for fk in select con.oid,con.conname,con.conrelid,con.conkey,c.relname
    from pg_constraint con join pg_class c on c.oid=con.conrelid join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and con.contype='f' and not exists(
      select 1 from pg_index i where i.indrelid=con.conrelid and i.indisvalid and i.indpred is null
        and (i.indkey::smallint[])[0:cardinality(con.conkey)-1]=con.conkey
    )
  loop
    select string_agg(quote_ident(a.attname),',' order by k.ord) into columns_sql
      from unnest(fk.conkey) with ordinality k(attnum,ord) join pg_attribute a on a.attrelid=fk.conrelid and a.attnum=k.attnum;
    execute format('create index if not exists %I on public.%I (%s)',left(fk.conname,50)||'_fk_idx',fk.relname,columns_sql);
  end loop;
end $$;
notify pgrst, 'reload schema';
