-- The phone is a password-login identifier. Track registration attempts
-- server-side because account creation uses the Auth Admin API without SMS.
create table if not exists public.phone_signup_attempts (
  id bigint generated always as identity primary key,
  phone_hash text not null,
  ip_hash text not null,
  created_at timestamptz not null default pg_catalog.now(),
  check (phone_hash ~ '^[0-9a-f]{64}$'),
  check (ip_hash ~ '^[0-9a-f]{64}$')
);
create index if not exists phone_signup_attempts_phone_time_idx
  on public.phone_signup_attempts(phone_hash, created_at desc);
create index if not exists phone_signup_attempts_ip_time_idx
  on public.phone_signup_attempts(ip_hash, created_at desc);
alter table public.phone_signup_attempts enable row level security;
revoke all on public.phone_signup_attempts from public, anon, authenticated;
grant all on public.phone_signup_attempts to service_role;

create or replace function public.consume_phone_signup_rate_limit(
  p_phone_hash text,
  p_ip_hash text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  recent_phone_attempts integer;
  recent_ip_attempts integer;
begin
  if p_phone_hash !~ '^[0-9a-f]{64}$' or p_ip_hash !~ '^[0-9a-f]{64}$' then
    return false;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('phone-signup:' || p_phone_hash, 0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('ip-signup:' || p_ip_hash, 0)
  );

  delete from public.phone_signup_attempts
    where created_at < pg_catalog.now() - interval '24 hours';

  select count(*) into recent_phone_attempts
    from public.phone_signup_attempts
    where phone_hash = p_phone_hash
      and created_at > pg_catalog.now() - interval '24 hours';
  select count(*) into recent_ip_attempts
    from public.phone_signup_attempts
    where ip_hash = p_ip_hash
      and created_at > pg_catalog.now() - interval '1 hour';

  if recent_phone_attempts >= 3 or recent_ip_attempts >= 20 then
    return false;
  end if;

  insert into public.phone_signup_attempts(phone_hash, ip_hash)
    values (p_phone_hash, p_ip_hash);
  return true;
end;
$$;
revoke all on function public.consume_phone_signup_rate_limit(text, text)
  from public, anon, authenticated;
grant execute on function public.consume_phone_signup_rate_limit(text, text)
  to service_role;

-- Contract-first records may only auto-attach to unlinked customer rows.
-- An account registered with an unverified username phone is not proof of
-- ownership, even when the entered name and number match a contract.
create or replace function public.attach_pending_contract_to_customer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  matched_contract public.pending_contract_records%rowtype;
  contract_matches integer;
  customer_matches integer;
begin
  if new.auth_user_id is not null or new.contract_number is not null
      or new.phone is null or btrim(new.full_name) = '' then
    return new;
  end if;
  select count(*) into customer_matches from public.customers c
    where c.auth_user_id is null and c.contract_number is null
      and lower(btrim(c.full_name)) = lower(btrim(new.full_name))
      and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(new.phone);
  if customer_matches <> 1 then return new; end if;
  select count(*) into contract_matches from public.pending_contract_records p
    where lower(btrim(p.full_name)) = lower(btrim(new.full_name))
      and public.normalize_tr_phone(p.phone) = public.normalize_tr_phone(new.phone);
  if contract_matches <> 1 then return new; end if;
  select * into matched_contract from public.pending_contract_records p
    where lower(btrim(p.full_name)) = lower(btrim(new.full_name))
      and public.normalize_tr_phone(p.phone) = public.normalize_tr_phone(new.phone)
    for update;
  update public.customers set
    national_or_tax_id = coalesce(matched_contract.national_or_tax_id, national_or_tax_id),
    contract_number = matched_contract.contract_number,
    contract_status = 'approved',
    assigned_advisor_id = matched_contract.assigned_advisor_id,
    folder_id = matched_contract.folder_id
    where id = new.id and auth_user_id is null;
  if matched_contract.storage_path is not null then
    insert into public.customer_contract_documents (
      customer_id, storage_path, file_name, content_type, uploaded_by
    ) values (
      new.id, matched_contract.storage_path, matched_contract.file_name,
      matched_contract.content_type, matched_contract.uploaded_by
    ) on conflict (customer_id) do update set
      storage_path = excluded.storage_path, file_name = excluded.file_name,
      content_type = excluded.content_type, uploaded_by = excluded.uploaded_by,
      created_at = pg_catalog.now();
  end if;
  delete from public.pending_contract_records where id = matched_contract.id;
  return new;
end;
$$;

-- Keep the existing contract-record workflow, but exclude user-owned account
-- shells from both automatic matching paths. Unmatched contracts remain in
-- pending_contract_records for an explicit management decision.
create or replace function public.create_contract_record(
  p_full_name text,
  p_national_or_tax_id text,
  p_phone text,
  p_assigned_advisor_id uuid,
  p_contract_date date,
  p_folder_id uuid default null,
  p_contract_storage_path text default null,
  p_contract_file_name text default null,
  p_contract_content_type text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  digits text;
  normalized_phone text;
  contract_year integer;
  serial_number integer;
  generated_contract_number text;
  matching_customers integer;
  target_customer_id uuid;
  extension text;
begin
  if not (select public.can_manage_finance()) then
    raise exception 'Only management or accounting can create contracts';
  end if;
  if nullif(btrim(p_full_name), '') is null or p_contract_date is null then
    raise exception 'Customer name and contract date are required';
  end if;
  if not exists (select 1 from public.profiles p
      where p.id = p_assigned_advisor_id and p.staff_role = 'sales_advisor') then
    raise exception 'A valid sales advisor must be assigned';
  end if;

  digits := pg_catalog.regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  if length(digits) = 10 and left(digits, 1) = '5' then
    normalized_phone := '+90' || digits;
  elsif length(digits) = 11 and left(digits, 1) = '0' and substr(digits, 2, 1) = '5' then
    normalized_phone := '+90' || substr(digits, 2);
  elsif length(digits) = 12 and left(digits, 2) = '90' and substr(digits, 3, 1) = '5' then
    normalized_phone := '+' || digits;
  else
    raise exception 'Phone must be a valid Turkish mobile number';
  end if;

  if p_contract_storage_path is not null then
    extension := lower(split_part(coalesce(p_contract_file_name, ''), '.', -1));
    if extension not in ('pdf', 'doc', 'docx')
      or p_contract_content_type not in ('application/pdf', 'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document') then
      raise exception 'Contract file must be a PDF or Word document';
    end if;
    if not exists (select 1 from storage.objects o
      where o.bucket_id = 'customer-contracts' and o.name = p_contract_storage_path
        and split_part(o.name, '/', 1) = (select auth.uid())::text) then
      raise exception 'The private contract upload was not found for this staff account';
    end if;
  elsif p_contract_file_name is not null or p_contract_content_type is not null then
    raise exception 'Incomplete contract file information';
  end if;

  contract_year := extract(year from p_contract_date)::integer;
  insert into public.customer_contract_counters as counters (contract_year, last_number)
    values (contract_year, 1)
    on conflict (contract_year) do update set last_number = counters.last_number + 1
    returning last_number into serial_number;
  if serial_number > 999999 then
    raise exception 'The contract sequence for % is full', contract_year;
  end if;
  generated_contract_number := 'S/' || contract_year::text || lpad(serial_number::text, 6, '0');

  select count(*) into matching_customers from public.customers c
    where c.auth_user_id is null and c.contract_number is null
      and lower(btrim(c.full_name)) = lower(btrim(p_full_name))
      and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(normalized_phone);
  if matching_customers = 1 then
    select c.id into target_customer_id from public.customers c
      where c.auth_user_id is null and c.contract_number is null
        and lower(btrim(c.full_name)) = lower(btrim(p_full_name))
        and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(normalized_phone)
      for update;
    update public.customers set
      national_or_tax_id = coalesce(nullif(btrim(p_national_or_tax_id), ''), national_or_tax_id),
      contract_number = generated_contract_number, contract_status = 'approved',
      assigned_advisor_id = p_assigned_advisor_id, folder_id = p_folder_id
      where id = target_customer_id and auth_user_id is null;
    if p_contract_storage_path is not null then
      insert into public.customer_contract_documents (
        customer_id, storage_path, file_name, content_type, uploaded_by
      ) values (target_customer_id, p_contract_storage_path, p_contract_file_name,
        p_contract_content_type, (select auth.uid()));
    end if;
    return target_customer_id;
  end if;

  insert into public.pending_contract_records (
    full_name, national_or_tax_id, phone, contract_number, contract_date,
    assigned_advisor_id, folder_id, storage_path, file_name, content_type, uploaded_by
  ) values (
    btrim(p_full_name), nullif(btrim(p_national_or_tax_id), ''), normalized_phone,
    generated_contract_number, p_contract_date, p_assigned_advisor_id, p_folder_id,
    p_contract_storage_path, p_contract_file_name, p_contract_content_type, (select auth.uid())
  ) returning id into target_customer_id;
  return target_customer_id;
end;
$$;
revoke all on function public.create_contract_record(text, text, text, uuid, date, uuid, text, text, text)
  from public, anon;
grant execute on function public.create_contract_record(text, text, text, uuid, date, uuid, text, text, text)
  to authenticated;

-- A no-SMS registration cannot prove ownership of an existing contract phone.
-- Create an uncontracted account shell for its Auth identity and leave any
-- matching preloaded contract unattached until management has confirmed it.
create or replace function public.ensure_my_customer_record(p_full_name text default '')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_row auth.users%rowtype;
  customer_id uuid;
  account_phone text;
  normalized_phone text;
  customer_name text;
begin
  select * into user_row
    from auth.users u where u.id = (select auth.uid());
  if user_row.id is null then
    raise exception 'An authenticated account is required';
  end if;
  if exists (select 1 from public.profiles p
      where p.id = user_row.id
        and (p.role = 'admin'::public.app_role or p.staff_role is not null)) then
    raise exception 'Staff accounts cannot create customer records';
  end if;

  select c.id into customer_id from public.customers c
    where c.auth_user_id = user_row.id limit 1;
  if customer_id is not null then return customer_id; end if;

  account_phone := coalesce(
    nullif(user_row.raw_user_meta_data ->> 'username_phone', ''),
    user_row.phone
  );
  normalized_phone := public.normalize_tr_phone(account_phone);
  if normalized_phone is null or length(normalized_phone) <> 12
      or left(normalized_phone, 2) <> '90' then
    raise exception 'A valid Turkish mobile username is required';
  end if;
  customer_name := coalesce(
    nullif(btrim(p_full_name), ''),
    nullif(btrim(user_row.raw_user_meta_data ->> 'full_name'), ''),
    'Müşteri'
  );

  insert into public.customers (
    auth_user_id, full_name, national_or_tax_id, phone, email, address,
    contract_number, contract_status
  ) values (
    user_row.id, customer_name, null, '+' || normalized_phone, '', '', null, 'pending'
  ) on conflict (auth_user_id) do nothing
  returning id into customer_id;

  if customer_id is null then
    select c.id into customer_id from public.customers c
      where c.auth_user_id = user_row.id limit 1;
  end if;
  return customer_id;
end;
$$;
grant execute on function public.ensure_my_customer_record(text) to authenticated;

-- A manager confirms the person outside the app, then joins the pending
-- username account to its existing contract. The username alone never grants
-- access to a preloaded customer record.
create or replace function public.link_customer_account(
  p_contract_customer_id uuid,
  p_account_customer_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract_customer public.customers%rowtype;
  v_account_customer public.customers%rowtype;
  v_auth_user_id uuid;
begin
  if not (select public.can_manage_finance()) then
    raise exception 'Only management or accounting can link customer accounts';
  end if;
  if p_contract_customer_id = p_account_customer_id then
    raise exception 'The account and contract records must be different';
  end if;

  select * into v_contract_customer
    from public.customers c where c.id = p_contract_customer_id for update;
  select * into v_account_customer
    from public.customers c where c.id = p_account_customer_id for update;
  if v_contract_customer.id is null or v_contract_customer.auth_user_id is not null
      or v_contract_customer.contract_number is null then
    raise exception 'The contract record is missing, already linked, or has no contract';
  end if;
  if v_account_customer.id is null or v_account_customer.auth_user_id is null
      or v_account_customer.contract_number is not null then
    raise exception 'The pending account record is missing or already has a contract';
  end if;
  if public.normalize_tr_phone(v_contract_customer.phone)
      is distinct from public.normalize_tr_phone(v_account_customer.phone) then
    raise exception 'The contract and account phone numbers do not match';
  end if;
  if exists (select 1 from public.profiles p
      where p.id = v_account_customer.auth_user_id
        and (p.role = 'admin'::public.app_role or p.staff_role is not null)) then
    raise exception 'A staff account cannot be linked as a customer';
  end if;

  v_auth_user_id := v_account_customer.auth_user_id;
  if exists (select 1 from public.customer_contract_documents d
      where d.customer_id = v_account_customer.id) then
    raise exception 'The pending account has a contract document; resolve it before linking';
  end if;

  update public.customers set auth_user_id = null
    where id = v_account_customer.id;
  update public.support_tickets t
    set customer_id = v_contract_customer.id,
        assigned_staff_id = case
          when t.channel = 'advisor' then v_contract_customer.assigned_advisor_id
          else t.assigned_staff_id
        end
    where t.customer_id = v_account_customer.id;
  update public.promissory_notes n
    set customer_id = v_contract_customer.id
    where n.customer_id = v_account_customer.id;
  update public.payment_submissions s
    set customer_id = v_contract_customer.id
    where s.customer_id = v_account_customer.id;
  update public.notifications n
    set customer_id = v_contract_customer.id
    where n.customer_id = v_account_customer.id;
  update public.customers set auth_user_id = v_auth_user_id
    where id = v_contract_customer.id;
  delete from public.customers where id = v_account_customer.id;

  return p_contract_customer_id;
end;
$$;
revoke all on function public.link_customer_account(uuid, uuid)
  from public, anon;
grant execute on function public.link_customer_account(uuid, uuid)
  to authenticated;

create or replace function public.link_pending_contract_account(
  p_pending_contract_id uuid,
  p_account_customer_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pending public.pending_contract_records%rowtype;
  v_account public.customers%rowtype;
  v_customer_id uuid;
  v_auth_user_id uuid;
begin
  if not (select public.can_manage_finance()) then
    raise exception 'Only management or accounting can link customer accounts';
  end if;
  select * into v_pending
    from public.pending_contract_records p
    where p.id = p_pending_contract_id for update;
  select * into v_account
    from public.customers c
    where c.id = p_account_customer_id for update;
  if v_pending.id is null or v_account.id is null
      or v_account.auth_user_id is null or v_account.contract_number is not null then
    raise exception 'The pending contract or account record is missing';
  end if;
  if public.normalize_tr_phone(v_pending.phone)
      is distinct from public.normalize_tr_phone(v_account.phone) then
    raise exception 'The contract and account phone numbers do not match';
  end if;
  if exists (select 1 from public.profiles p
      where p.id = v_account.auth_user_id
        and (p.role = 'admin'::public.app_role or p.staff_role is not null)) then
    raise exception 'A staff account cannot be linked as a customer';
  end if;

  v_auth_user_id := v_account.auth_user_id;
  update public.customers set auth_user_id = null
    where id = v_account.id;
  insert into public.customers (
    auth_user_id, full_name, national_or_tax_id, phone, email, address,
    contract_number, contract_status, assigned_advisor_id, folder_id
  ) values (
    v_auth_user_id, v_pending.full_name, v_pending.national_or_tax_id,
    v_pending.phone, '', '', v_pending.contract_number, 'approved',
    v_pending.assigned_advisor_id, v_pending.folder_id
  ) returning id into v_customer_id;

  if v_pending.storage_path is not null then
    insert into public.customer_contract_documents (
      customer_id, storage_path, file_name, content_type, uploaded_by
    ) values (
      v_customer_id, v_pending.storage_path, v_pending.file_name,
      v_pending.content_type, v_pending.uploaded_by
    );
  end if;
  update public.support_tickets t
    set customer_id = v_customer_id,
        assigned_staff_id = case
          when t.channel = 'advisor' then v_pending.assigned_advisor_id
          else t.assigned_staff_id
        end
    where t.customer_id = v_account.id;
  update public.notifications n
    set customer_id = v_customer_id
    where n.customer_id = v_account.id;
  delete from public.customers where id = v_account.id;
  delete from public.pending_contract_records where id = v_pending.id;
  return v_customer_id;
end;
$$;
revoke all on function public.link_pending_contract_account(uuid, uuid)
  from public, anon;
grant execute on function public.link_pending_contract_account(uuid, uuid)
  to authenticated;

-- Do not attach contracts merely because an account chose the same phone
-- username. Phone verification is intentionally absent in this product flow.
drop trigger if exists link_verified_customer_after_insert on auth.users;
drop trigger if exists link_verified_customer_after_phone_change on auth.users;
drop trigger if exists link_verified_user_after_customer_insert on public.customers;
drop trigger if exists link_verified_user_after_customer_phone_change on public.customers;

notify pgrst, 'reload schema';
