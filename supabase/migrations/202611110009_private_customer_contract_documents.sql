-- Private contract documents: each contract file is linked to exactly one
-- customer row. Storage paths are opaque and cannot be read without a matching
-- authorized row in this table.
create table if not exists public.customer_contract_documents (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null unique references public.customers(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  content_type text not null check (content_type in (
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  )),
  uploaded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.customer_contract_documents enable row level security;
revoke all on public.customer_contract_documents from public, anon;
grant select on public.customer_contract_documents to authenticated;
create policy "contract_document_customer_or_assigned_staff_read"
  on public.customer_contract_documents for select to authenticated
  using ((select public.can_access_customer(customer_id)));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'customer-contracts', 'customer-contracts', false, 20971520,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "contract_staff_upload_private" on storage.objects;
create policy "contract_staff_upload_private" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'customer-contracts' and (select public.is_staff()));

drop policy if exists "contract_document_authorized_read" on storage.objects;
create policy "contract_document_authorized_read" on storage.objects
  for select to authenticated using (
    bucket_id = 'customer-contracts' and exists (
      select 1 from public.customer_contract_documents d
      where d.storage_path = storage.objects.name
    )
  );

drop policy if exists "contract_staff_delete_unlinked_or_finance" on storage.objects;
create policy "contract_staff_delete_unlinked_or_finance" on storage.objects
  for delete to authenticated using (
    bucket_id = 'customer-contracts'
    and (select public.is_staff())
    and (
      (select public.can_manage_finance())
      or not exists (
        select 1 from public.customer_contract_documents d
        where d.storage_path = storage.objects.name
      )
    )
  );

-- Replace the old RPC so a contract cannot be registered without an existing
-- private PDF/Word upload, and persist the exact object-to-customer link in
-- the same database transaction as the contract assignment.
drop function if exists public.create_customer_with_contract(
  text, text, text, uuid, date, uuid
);

create function public.create_customer_with_contract(
  p_full_name text,
  p_national_or_tax_id text,
  p_phone text,
  p_assigned_advisor_id uuid,
  p_contract_date date,
  p_folder_id uuid,
  p_contract_storage_path text,
  p_contract_file_name text,
  p_contract_content_type text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  digits text;
  normalized_phone text;
  contract_year integer;
  serial_number integer;
  generated_contract_number text;
  pending_count integer;
  target_customer_id uuid;
  file_extension text;
begin
  if not (select public.can_manage_finance()) then
    raise exception 'Only management or accounting can create customer contracts';
  end if;
  if nullif(btrim(p_full_name), '') is null then
    raise exception 'Customer name is required';
  end if;
  if p_contract_date is null then
    raise exception 'Contract date is required';
  end if;
  if nullif(btrim(p_contract_file_name), '') is null
    or nullif(btrim(p_contract_storage_path), '') is null then
    raise exception 'A contract PDF or Word file is required';
  end if;
  file_extension := lower(split_part(p_contract_file_name, '.', -1));
  if file_extension not in ('pdf', 'doc', 'docx') then
    raise exception 'Contract file must be a PDF or Word document';
  end if;
  if (file_extension = 'pdf' and p_contract_content_type <> 'application/pdf')
    or (file_extension = 'doc' and p_contract_content_type <> 'application/msword')
    or (file_extension = 'docx' and p_contract_content_type <>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document') then
    raise exception 'Contract file extension and content type do not match';
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'customer-contracts'
      and o.name = p_contract_storage_path
      and split_part(o.name, '/', 1) = (select auth.uid())::text
  ) then
    raise exception 'The private contract upload was not found for this staff account';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = p_assigned_advisor_id and p.staff_role = 'sales_advisor'
  ) then
    raise exception 'A valid sales advisor must be assigned';
  end if;

  digits := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  if length(digits) = 10 then
    normalized_phone := '+90' || digits;
  elsif length(digits) = 11 and left(digits, 1) = '0' then
    normalized_phone := '+90' || substr(digits, 2);
  elsif length(digits) = 12 and left(digits, 2) = '90' then
    normalized_phone := '+' || digits;
  else
    raise exception 'Phone must contain 10 digits or 11 digits starting with 0';
  end if;

  select count(*) into pending_count
  from public.customers c
  where c.contract_status = 'pending'
    and c.auth_user_id is not null
    and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(normalized_phone);
  if pending_count > 1 then
    raise exception 'More than one pending account uses this phone number';
  end if;

  contract_year := extract(year from p_contract_date)::integer;
  insert into public.customer_contract_counters as counters (contract_year, last_number)
  values (contract_year, 1)
  on conflict (contract_year) do update
    set last_number = counters.last_number + 1
  returning last_number into serial_number;
  if serial_number > 999999 then
    raise exception 'The contract sequence for % is full', contract_year;
  end if;
  generated_contract_number := 'S/' || contract_year::text
    || lpad(serial_number::text, 6, '0');

  if pending_count = 1 then
    update public.customers c set
      full_name = btrim(p_full_name),
      national_or_tax_id = nullif(btrim(p_national_or_tax_id), ''),
      phone = normalized_phone,
      email = '',
      address = 'Karasu / Sakarya',
      contract_number = generated_contract_number,
      contract_status = 'approved',
      assigned_advisor_id = p_assigned_advisor_id,
      folder_id = p_folder_id
    where c.contract_status = 'pending'
      and c.auth_user_id is not null
      and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(normalized_phone)
    returning c.id into target_customer_id;
  else
    insert into public.customers (
      full_name, national_or_tax_id, phone, email, address, contract_number,
      contract_status, assigned_advisor_id, folder_id
    ) values (
      btrim(p_full_name), nullif(btrim(p_national_or_tax_id), ''),
      normalized_phone, '', 'Karasu / Sakarya', generated_contract_number,
      'approved', p_assigned_advisor_id, p_folder_id
    ) returning id into target_customer_id;
  end if;

  insert into public.customer_contract_documents (
    customer_id, storage_path, file_name, content_type, uploaded_by
  ) values (
    target_customer_id, p_contract_storage_path, btrim(p_contract_file_name),
    p_contract_content_type, (select auth.uid())
  )
  on conflict (customer_id) do update set
    storage_path = excluded.storage_path,
    file_name = excluded.file_name,
    content_type = excluded.content_type,
    uploaded_by = excluded.uploaded_by,
    created_at = now();

  return target_customer_id;
end;
$$;

revoke all on function public.create_customer_with_contract(
  text, text, text, uuid, date, uuid, text, text, text
) from public, anon;
grant execute on function public.create_customer_with_contract(
  text, text, text, uuid, date, uuid, text, text, text
) to authenticated;

notify pgrst, 'reload schema';

-- Attachments are private and inherit the exact parent ticket's RLS boundary.
insert into storage.buckets (id, name, public, file_size_limit)
values ('message-attachments', 'message-attachments', false, 104857600)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = null;

drop policy if exists "ticket_attachment_authorized_upload" on storage.objects;
create policy "ticket_attachment_authorized_upload" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'message-attachments'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and (select public.can_access_ticket((storage.foldername(name))[1]::uuid))
  );

drop policy if exists "ticket_attachment_authorized_read" on storage.objects;
create policy "ticket_attachment_authorized_read" on storage.objects
  for select to authenticated using (
    bucket_id = 'message-attachments' and exists (
      select 1 from public.ticket_messages m
      where m.attachment_object_path = storage.objects.name
    )
  );

drop policy if exists "ticket_attachment_owner_delete_unlinked" on storage.objects;
create policy "ticket_attachment_owner_delete_unlinked" on storage.objects
  for delete to authenticated using (
    bucket_id = 'message-attachments'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and (select public.can_access_ticket((storage.foldername(name))[1]::uuid))
    and not exists (
      select 1 from public.ticket_messages m
      where m.attachment_object_path = storage.objects.name
    )
  );
