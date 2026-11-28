-- Customer account identity is separate from retained company business records.
alter table public.profiles add column if not exists deleted_at timestamptz;
alter table public.customers add column if not exists is_demo boolean not null default false;
alter table public.customers add column if not exists down_payment_amount numeric(14,2) not null default 0 check (down_payment_amount >= 0);
alter table public.profiles drop constraint if exists profiles_id_fkey;

create or replace function public.portal_account_active()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from auth.users u join public.profiles p on p.id=u.id
    where u.id=(select auth.uid()) and p.deleted_at is null)
$$;
revoke all on function public.portal_account_active() from public,anon;
grant execute on function public.portal_account_active() to authenticated;
do $$ declare t record; begin
  for t in select tablename from pg_tables where schemaname='public' and rowsecurity loop
    execute format('create policy portal_active_account on public.%I as restrictive for all to authenticated using ((select public.portal_account_active())) with check ((select public.portal_account_active()))',t.tablename);
  end loop;
end $$;
create policy portal_active_account on storage.objects as restrictive for all to authenticated
using ((select public.portal_account_active())) with check ((select public.portal_account_active()));

create or replace function public.portal_save_account(p_user_id uuid,p_name text,p_phone text)
returns void language plpgsql security definer set search_path = '' as $$
declare normalized text := public.normalize_tr_phone(p_phone); begin
  if not exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_user_id and p.deleted_at is null) then raise exception 'Account unavailable'; end if;
  if char_length(btrim(p_name)) not between 3 and 100 or normalized !~ '^905[0-9]{9}$' then raise exception 'Invalid account details'; end if;
  if exists(select 1 from public.staff_account_roster where public.normalize_tr_phone(phone)=normalized)
    and not exists(select 1 from public.profiles where id=p_user_id and public.normalize_tr_phone(contact_phone)=normalized) then raise exception 'Reserved phone'; end if;
  update public.profiles set full_name=btrim(p_name),contact_phone='+'||normalized where id=p_user_id;
  update public.customers set full_name=btrim(p_name),phone='+'||normalized where auth_user_id=p_user_id;
end $$;
revoke all on function public.portal_save_account(uuid,text,text) from public,anon,authenticated;
grant execute on function public.portal_save_account(uuid,text,text) to service_role;

create or replace function public.portal_delete_account(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.profiles where id=p_user_id and role='customer' and staff_role is null and deleted_at is null for update;
  if not found then raise exception 'Customer account required' using errcode='42501'; end if;
  -- Preserve only the attribution tombstone needed by retained company messages.
  update public.profiles set full_name='Silinen hesap',contact_phone=null,deleted_at=now() where id=p_user_id;
  update public.customers set auth_user_id=null,
    full_name=case when contract_number is null then 'Silinen hesap' else full_name end,
    phone=case when contract_number is null then '' else phone end,
    email='',address=case when contract_number is null then '' else address end
    where auth_user_id=p_user_id;
  -- Ownership metadata must not keep the deleted Auth identity alive. The private
  -- business documents retain their existing path and staff access rules.
  update storage.objects set owner=null,owner_id=null where owner_id=p_user_id::text or owner=p_user_id;
  -- Auth cascades remove sessions, refresh tokens, device tokens and preferences.
  delete from auth.users where id=p_user_id;
end $$;
revoke all on function public.portal_delete_account(uuid) from public,anon,authenticated;
grant execute on function public.portal_delete_account(uuid) to service_role;

create schema if not exists portal_private;
create or replace function portal_private.guard_customer_email()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if nullif(old.email,'') is not null and new.email is distinct from old.email
    and exists(select 1 from public.profiles where id=old.id and role='customer' and staff_role is null) then
    raise exception 'E-posta adresi kayıttan sonra değiştirilemez.' using errcode='42501';
  end if;
  return new;
end $$;
revoke all on function portal_private.guard_customer_email() from public,anon,authenticated;
create trigger portal_immutable_customer_email before update of email on auth.users
for each row execute function portal_private.guard_customer_email();
notify pgrst,'reload schema';

create or replace function public.ensure_my_customer_record(p_full_name text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor uuid:=(select auth.uid()); u auth.users%rowtype; target uuid; begin
  if actor is null or public.is_staff() then raise exception 'Customer session required' using errcode='42501'; end if;
  select * into u from auth.users where id=actor;
  if not found or not public.portal_account_active() then raise exception 'Account unavailable' using errcode='42501'; end if;
  select id into target from public.customers where auth_user_id=actor;
  if target is not null then return target; end if;
  insert into public.customers(auth_user_id,full_name,phone,email,contract_status)
  values(actor,coalesce(nullif(btrim(p_full_name),''),nullif(u.raw_user_meta_data->>'full_name',''),'Müşteri'),
    '+'||public.normalize_tr_phone(u.phone),coalesce(u.email,''),'pending')
  on conflict(auth_user_id) do nothing returning id into target;
  if target is null then select id into target from public.customers where auth_user_id=actor; end if;
  return target;
end $$;
revoke all on function public.ensure_my_customer_record(text) from public,anon;
grant execute on function public.ensure_my_customer_record(text) to authenticated;
