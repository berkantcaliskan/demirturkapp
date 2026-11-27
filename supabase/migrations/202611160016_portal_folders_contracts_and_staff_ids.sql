create function public.is_portal_manager()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
      and p.staff_id like 'Y%'
      and (p.staff_role = 'management' or (p.role = 'admin' and p.staff_role is null))
  );
$$;
revoke all on function public.is_portal_manager() from public, anon;
grant execute on function public.is_portal_manager() to authenticated;

drop policy staff_read_customer_folders on public.customer_folders;
drop policy staff_manage_customer_folders on public.customer_folders;
create policy customer_folders_read on public.customer_folders
  for select to authenticated using (
    (select public.is_staff()) and (created_by = (select auth.uid()) or (select public.is_portal_manager()))
  );
create policy customer_folders_create on public.customer_folders
  for insert to authenticated with check (
    (select public.is_staff()) and created_by = (select auth.uid())
  );
revoke update, delete on public.customer_folders from authenticated;

alter table public.customer_folders add unique (id, created_by);
create table public.customer_folder_memberships (
  owner_id uuid not null,
  customer_id uuid not null references public.customers(id) on delete cascade,
  folder_id uuid not null,
  primary key (owner_id, customer_id),
  foreign key (folder_id, owner_id) references public.customer_folders(id, created_by) on delete cascade
);
create index customer_folder_memberships_folder_id_idx on public.customer_folder_memberships(folder_id);
create index customer_folder_memberships_customer_id_idx on public.customer_folder_memberships(customer_id);
insert into public.customer_folder_memberships (owner_id, customer_id, folder_id)
select f.created_by, c.id, f.id
from public.customers c join public.customer_folders f on f.id = c.folder_id;
revoke all on public.customer_folder_memberships from public, anon, authenticated;
grant select on public.customer_folder_memberships to authenticated;
alter table public.customer_folder_memberships enable row level security;
create policy customer_folder_memberships_read on public.customer_folder_memberships
  for select to authenticated using (
    (select public.is_staff()) and (owner_id = (select auth.uid()) or (select public.is_portal_manager()))
    and public.can_access_customer(customer_id)
  );
revoke update (folder_id) on public.customers from authenticated;

create function public.assign_customer_to_portal_folder(p_customer_id uuid, p_folder_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if not public.is_staff() or not public.can_access_customer(p_customer_id) then
    raise exception 'Customer folder access denied' using errcode = '42501';
  end if;
  if p_folder_id is null then
    delete from public.customer_folder_memberships where owner_id = caller_id and customer_id = p_customer_id;
    return;
  end if;
  if not exists (select 1 from public.customer_folders where id = p_folder_id and created_by = caller_id) then
    raise exception 'Folder assignment requires a folder owned by the caller' using errcode = '42501';
  end if;
  insert into public.customer_folder_memberships (owner_id, customer_id, folder_id)
    values (caller_id, p_customer_id, p_folder_id)
    on conflict (owner_id, customer_id) do update set folder_id = excluded.folder_id;
end;
$$;
revoke all on function public.assign_customer_to_portal_folder(uuid, uuid) from public, anon;
grant execute on function public.assign_customer_to_portal_folder(uuid, uuid) to authenticated;

alter table public.pending_contract_records
  add column project_name text not null default '',
  add column unit_label text not null default '';

create function public.create_portal_contract(
  p_full_name text, p_national_or_tax_id text, p_phone text,
  p_assigned_advisor_id uuid, p_contract_date date, p_project_name text,
  p_unit_label text, p_contract_storage_path text, p_contract_file_name text,
  p_contract_content_type text
)
returns text language plpgsql security definer set search_path = '' as $$
declare
  record_id uuid;
  contract_no text;
  project text := btrim(coalesce(p_project_name, ''));
  unit text := btrim(coalesce(p_unit_label, ''));
begin
  if not public.can_manage_finance() then
    raise exception 'Contract creation denied' using errcode = '42501';
  end if;
  if char_length(project) not between 1 and 120 or char_length(unit) > 80 then
    raise exception 'A project name and a valid unit label are required';
  end if;
  record_id := public.create_contract_record(p_full_name, p_national_or_tax_id, p_phone,
    p_assigned_advisor_id, p_contract_date, null, p_contract_storage_path,
    p_contract_file_name, p_contract_content_type);
  update public.pending_contract_records set project_name = project, unit_label = unit
    where id = record_id returning contract_number into contract_no;
  if not found then
    update public.customers set project_name = project, unit_label = unit
      where id = record_id returning contract_number into strict contract_no;
  end if;
  return contract_no;
end;
$$;
revoke all on function public.create_portal_contract(text, text, text, uuid, date, text, text, text, text, text) from public, anon;
grant execute on function public.create_portal_contract(text, text, text, uuid, date, text, text, text, text, text) to authenticated;

create policy contract_pending_finance_read on storage.objects
  for select to authenticated using (
    bucket_id = 'customer-contracts' and (select public.can_manage_finance())
    and exists (select 1 from public.pending_contract_records p where p.storage_path = storage.objects.name)
  );

create function public.list_portal_accounts()
returns table (id uuid, full_name text, staff_role text, staff_id text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_portal_manager() then
    raise exception 'Account directory access denied' using errcode = '42501';
  end if;
  return query select p.id, p.full_name,
    coalesce(p.staff_role, case when p.role = 'admin' then 'management' end), p.staff_id
    from public.profiles p where p.id <> (select auth.uid()) order by p.full_name, p.id;
end;
$$;
revoke all on function public.list_portal_accounts() from public, anon;
grant execute on function public.list_portal_accounts() to authenticated;

update public.profiles p set staff_id = replacement.new_id
from (values
  ('SD', 'ERT', '202601'), ('SD', 'HAZ', '202602'), ('SD', 'LEV', '202603'),
  ('M', 'OZL', '202600'), ('Y', 'BER', '202600'), ('Y', 'MUR', '202601')
) as ids(prefix, suffix, code)
cross join lateral (select ids.prefix || ids.code || '/' || ids.suffix as new_id) replacement
where p.staff_id ~ ('^' || ids.prefix || '[0-9]{6}/' || ids.suffix || '$')
  and p.staff_id <> replacement.new_id;

create or replace function public.link_pending_contract_account(
  p_pending_contract_id uuid,
  p_account_customer_id uuid
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  pending_contract public.pending_contract_records%rowtype;
  account_customer public.customers%rowtype;
begin
  if not (select public.can_manage_finance()) then
    raise exception 'Only management or accounting can link customer accounts';
  end if;

  select * into pending_contract from public.pending_contract_records
    where id = p_pending_contract_id for update;
  select * into account_customer from public.customers
    where id = p_account_customer_id for update;
  if pending_contract.id is null or account_customer.id is null
    or account_customer.auth_user_id is null or account_customer.contract_number is not null then
    raise exception 'The pending contract or account record is missing';
  end if;
  if public.normalize_tr_phone(pending_contract.phone)
    is distinct from public.normalize_tr_phone(account_customer.phone) then
    raise exception 'The contract and account phone numbers do not match';
  end if;
  if exists (select 1 from public.profiles p where p.id = account_customer.auth_user_id
    and (p.role = 'admin'::public.app_role or p.staff_role is not null)) then
    raise exception 'A staff account cannot be linked as a customer';
  end if;

  update public.customers set full_name = pending_contract.full_name,
    national_or_tax_id = coalesce(pending_contract.national_or_tax_id, national_or_tax_id),
    phone = pending_contract.phone, contract_number = pending_contract.contract_number,
    contract_status = 'approved', assigned_advisor_id = pending_contract.assigned_advisor_id,
    project_name = coalesce(nullif(pending_contract.project_name, ''), project_name),
    unit_label = coalesce(nullif(pending_contract.unit_label, ''), unit_label)
    where id = account_customer.id;

  if pending_contract.storage_path is not null then
    insert into public.customer_contract_documents (
      customer_id, storage_path, file_name, content_type, uploaded_by
    ) values (
      account_customer.id, pending_contract.storage_path, pending_contract.file_name,
      pending_contract.content_type, pending_contract.uploaded_by
    );
  end if;
  insert into public.customer_folder_memberships (owner_id, customer_id, folder_id)
    select f.created_by, account_customer.id, f.id from public.customer_folders f
    where f.id = pending_contract.folder_id
    on conflict (owner_id, customer_id) do nothing;
  delete from public.pending_contract_records where id = pending_contract.id;
  return account_customer.id;
end;
$$;

notify pgrst, 'reload schema';
