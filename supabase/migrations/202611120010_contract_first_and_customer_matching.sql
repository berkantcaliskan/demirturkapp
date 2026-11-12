-- Register a numbered contract before its customer exists. When a matching
-- customer row is later created, attach the contract by normalized name and
-- Turkish phone. Ambiguous matches intentionally remain unattached.

create table if not exists public.pending_contract_records (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  national_or_tax_id text,
  phone text not null,
  contract_number text not null unique,
  contract_date date not null,
  assigned_advisor_id uuid not null references public.profiles(id),
  folder_id uuid references public.customer_folders(id) on delete set null,
  storage_path text unique,
  file_name text,
  content_type text check (content_type is null or content_type in (
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  )),
  uploaded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check ((storage_path is null and file_name is null and content_type is null)
      or (storage_path is not null and file_name is not null and content_type is not null))
);
alter table public.pending_contract_records enable row level security;
revoke all on public.pending_contract_records from public, anon;
grant select on public.pending_contract_records to authenticated;
create policy "pending_contracts_finance_read" on public.pending_contract_records
  for select to authenticated using ((select public.can_manage_finance()));

create or replace function public.can_access_customer(target_customer_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select public.can_manage_finance())
    or exists (select 1 from public.customers c
      where c.id = target_customer_id and c.auth_user_id = (select auth.uid()))
    or exists (select 1 from public.customers c
      where c.id = target_customer_id and (select public.is_sales_advisor())
        and c.assigned_advisor_id = (select auth.uid()))
$$;

create or replace function public.attach_pending_contract_to_customer()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  matched_contract public.pending_contract_records%rowtype;
  contract_matches integer;
  customer_matches integer;
begin
  if new.contract_number is not null or new.phone is null or btrim(new.full_name) = '' then
    return new;
  end if;
  select count(*) into customer_matches from public.customers c
    where c.contract_number is null
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
    where id = new.id;
  if matched_contract.storage_path is not null then
    insert into public.customer_contract_documents (
      customer_id, storage_path, file_name, content_type, uploaded_by
    ) values (
      new.id, matched_contract.storage_path, matched_contract.file_name,
      matched_contract.content_type, matched_contract.uploaded_by
    ) on conflict (customer_id) do update set
      storage_path = excluded.storage_path, file_name = excluded.file_name,
      content_type = excluded.content_type, uploaded_by = excluded.uploaded_by,
      created_at = now();
  end if;
  delete from public.pending_contract_records where id = matched_contract.id;
  return new;
end;
$$;
drop trigger if exists attach_pending_contract_after_customer_insert on public.customers;
create trigger attach_pending_contract_after_customer_insert
  after insert on public.customers for each row
  execute function public.attach_pending_contract_to_customer();
revoke all on function public.attach_pending_contract_to_customer() from public, anon, authenticated;

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
returns uuid language plpgsql security definer set search_path = '' as $$
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
  digits := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  if length(digits) = 10 then normalized_phone := '+90' || digits;
  elsif length(digits) = 11 and left(digits, 1) = '0' then
    normalized_phone := '+90' || substr(digits, 2);
  elsif length(digits) = 12 and left(digits, 2) = '90' then
    normalized_phone := '+' || digits;
  else raise exception 'Phone must contain 10 digits or 11 digits starting with 0'; end if;

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
  if serial_number > 999999 then raise exception 'The contract sequence for % is full', contract_year; end if;
  generated_contract_number := 'S/' || contract_year::text || lpad(serial_number::text, 6, '0');

  select count(*) into matching_customers from public.customers c
    where c.contract_number is null
      and lower(btrim(c.full_name)) = lower(btrim(p_full_name))
      and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(normalized_phone);
  if matching_customers = 1 then
    select c.id into target_customer_id from public.customers c
      where c.contract_number is null
        and lower(btrim(c.full_name)) = lower(btrim(p_full_name))
        and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(normalized_phone)
      for update;
    update public.customers set
      national_or_tax_id = coalesce(nullif(btrim(p_national_or_tax_id), ''), national_or_tax_id),
      contract_number = generated_contract_number,
      contract_status = 'approved', assigned_advisor_id = p_assigned_advisor_id,
      folder_id = p_folder_id
      where id = target_customer_id;
    if p_contract_storage_path is not null then
      insert into public.customer_contract_documents (
        customer_id, storage_path, file_name, content_type, uploaded_by
      ) values (target_customer_id, p_contract_storage_path, p_contract_file_name,
        p_contract_content_type, (select auth.uid()));
    end if;
    return target_customer_id;
  end if;

  -- Keep existing customer rows without contracts as the matching target so
  -- contract-first entry can attach when the contract itself is created.
  select count(*) into matching_customers from public.customers c
    where c.contract_number is null
      and lower(btrim(c.full_name)) = lower(btrim(p_full_name))
      and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(normalized_phone);
  if matching_customers = 1 then
    select c.id into target_customer_id from public.customers c
      where c.contract_number is null
        and lower(btrim(c.full_name)) = lower(btrim(p_full_name))
        and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(normalized_phone)
      for update;
    update public.customers set
      national_or_tax_id = coalesce(nullif(btrim(p_national_or_tax_id), ''), national_or_tax_id),
      contract_number = generated_contract_number, contract_status = 'approved',
      assigned_advisor_id = p_assigned_advisor_id, folder_id = p_folder_id
      where id = target_customer_id;
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
notify pgrst, 'reload schema';
