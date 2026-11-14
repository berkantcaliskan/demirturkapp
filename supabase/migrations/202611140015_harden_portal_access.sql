-- Keep direct writes limited to the fields used by the mobile app. The
-- existing RPCs own contract linkage, ticket routing and account creation.
revoke all on public.profiles, public.customers, public.support_tickets,
  public.payment_submissions, public.ticket_messages, public.notifications,
  public.staff_notifications, public.promissory_notes, public.bank_accounts,
  public.customer_folders, public.customer_contract_documents,
  public.pending_contract_records, public.push_devices, public.user_preferences
  from public, anon;
revoke insert, update, delete on public.customer_contract_documents,
  public.pending_contract_records from authenticated;
revoke insert, update, delete on public.profiles, public.customers,
  public.support_tickets, public.payment_submissions, public.ticket_messages,
  public.notifications, public.staff_notifications from public, anon, authenticated;
revoke update (full_name) on public.profiles from public, anon, authenticated;
revoke update (is_resolved, updated_at) on public.support_tickets from public, anon, authenticated;
revoke update (status, rejection_reason, reviewed_at, reviewed_by)
  on public.payment_submissions from public, anon, authenticated;
revoke update (is_read) on public.notifications from public, anon, authenticated;

grant update (folder_id, assigned_advisor_id) on public.customers to authenticated;
grant insert (note_id, customer_id, receipt_object_path, payment_method, customer_note),
  update (status, rejection_reason, reviewed_at, reviewed_by)
  on public.payment_submissions to authenticated;
grant insert (ticket_id, sender_id, body, attachment_object_path)
  on public.ticket_messages to authenticated;
grant insert (customer_id, title, body, type), update (is_read)
  on public.notifications to authenticated;
grant update (is_read) on public.staff_notifications to authenticated;

drop policy if exists "tickets_customer_create_own" on public.support_tickets;
drop policy if exists "tickets_staff_update_scoped" on public.support_tickets;

-- RLS only applies to row operations, so remove default table privileges for
-- operations that the client should never perform, including TRUNCATE.
revoke truncate, references, trigger, maintain on public.profiles, public.customers,
  public.support_tickets, public.ticket_messages, public.promissory_notes,
  public.payment_submissions, public.notifications, public.staff_notifications,
  public.bank_accounts, public.customer_folders, public.customer_contract_documents,
  public.pending_contract_records, public.push_devices, public.user_preferences
  from public, anon, authenticated;

revoke truncate, references, trigger, maintain on public.push_outbox,
  public.customer_contract_counters, public.staff_account_roster,
  public.staff_provisioning_access, public.phone_signup_attempts
  from public, anon, authenticated;

revoke execute on function public.is_admin(), public.is_staff(),
  public.is_sales_advisor(), public.can_manage_finance(), public.current_customer_id(),
  public.can_access_customer(uuid), public.can_access_ticket(uuid) from public, anon;
revoke execute on function public.handle_new_user(), public.set_ticket_updated_at(),
  public.notify_for_ticket_message(), public.notify_payment_submission_change(),
  public.enqueue_notification_push() from public, anon, authenticated;

-- The legacy contract API automatically matched accounts by phone. V10 uses
-- create_contract_record and the explicit linking RPCs instead.
revoke execute on function public.create_customer_with_contract(
  text, text, text, uuid, date, uuid, text, text, text
) from public, anon, authenticated;

-- The Auth account's phone is authoritative. User-editable metadata must
-- never establish the phone number used by the manual contract link workflow.
create or replace function public.ensure_my_customer_record(p_full_name text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  account_id uuid := (select auth.uid());
  account_phone text;
  account_name text;
  customer_id uuid;
begin
  if account_id is null or (select public.is_staff()) then
    raise exception 'A customer session is required' using errcode = '42501';
  end if;

  select c.id into customer_id from public.customers c where c.auth_user_id = account_id;
  if customer_id is not null then return customer_id; end if;

  select public.normalize_tr_phone(u.phone), u.raw_user_meta_data ->> 'full_name'
    into account_phone, account_name
    from auth.users u where u.id = account_id;
  if account_phone is null or account_phone !~ '^905[0-9]{9}$' then
    raise exception 'A valid Turkish mobile username is required';
  end if;

  insert into public.customers (auth_user_id, full_name, phone, contract_status)
  values (account_id, coalesce(nullif(btrim(p_full_name), ''),
    nullif(btrim(account_name), ''), 'Müşteri'), '+' || account_phone, 'pending')
  on conflict (auth_user_id) do nothing returning id into customer_id;
  if customer_id is null then
    select c.id into customer_id from public.customers c where c.auth_user_id = account_id;
  end if;
  return customer_id;
end;
$$;

-- Keep the review state server-controlled. Lock the note before accepting a
-- receipt so simultaneous submissions cannot both enter the review queue.
create function public.validate_payment_submission()
returns trigger language plpgsql security definer set search_path = '' as $$
declare note_state public.note_status;
begin
  if tg_op = 'INSERT' then
    if new.customer_id is distinct from (select public.current_customer_id()) then
      raise exception 'A linked customer session is required' using errcode = '42501';
    end if;
    select n.status into note_state from public.promissory_notes n
      where n.id = new.note_id and n.customer_id = new.customer_id for update;
    if note_state is null or note_state not in ('pending', 'overdue') then
      raise exception 'This note cannot receive a receipt';
    end if;
    if split_part(new.receipt_object_path, '/', 1) <> new.customer_id::text
      or not exists (select 1 from storage.objects o
        where o.bucket_id = 'payment-receipts' and o.name = new.receipt_object_path) then
      raise exception 'A receipt uploaded for this customer is required';
    end if;
    return new;
  end if;

  if new.status not in ('approved', 'rejected') or old.status <> 'submitted' then
    raise exception 'This receipt has already been reviewed or the decision is invalid';
  end if;
  new.reviewed_by := (select auth.uid());
  new.reviewed_at := pg_catalog.now();
  return new;
end;
$$;

create trigger payment_submission_validate before insert
  or update of status, rejection_reason, reviewed_at, reviewed_by
  on public.payment_submissions for each row execute function public.validate_payment_submission();
revoke execute on function public.validate_payment_submission() from public, anon, authenticated;

create policy "receipt_owner_delete_unsubmitted" on storage.objects
  as restrictive for delete to authenticated using (
    bucket_id <> 'payment-receipts'
    or not exists (select 1 from public.payment_submissions p
      where p.receipt_object_path = storage.objects.name)
  );

-- Match a linked attachment to both its message's ticket and its sender.
-- The read policy also protects objects referenced before this migration.
create or replace function public.validate_ticket_attachment()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.attachment_object_path is not null and (
      split_part(new.attachment_object_path, '/', 1) <> new.ticket_id::text
      or split_part(new.attachment_object_path, '/', 2) <> new.sender_id::text
      or not exists (select 1 from storage.objects o
        where o.bucket_id = 'message-attachments' and o.name = new.attachment_object_path)
  ) then
    raise exception 'The attachment must be uploaded by the sender for this conversation';
  end if;
  return new;
end;
$$;

create trigger ticket_message_validate_attachment before insert or update of attachment_object_path
  on public.ticket_messages for each row execute function public.validate_ticket_attachment();
revoke execute on function public.validate_ticket_attachment() from public, anon, authenticated;

-- Older pending profiles may have been created before Auth became the only
-- source of the login phone. Verify it when moving ownership onto a contract.
create function public.validate_contract_auth_link()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.auth_user_id is null or new.contract_number is null then return new; end if;
  if tg_op = 'UPDATE' and old.auth_user_id is not distinct from new.auth_user_id
    and old.contract_number is not distinct from new.contract_number then
    return new;
  end if;
  if not exists (
    select 1 from auth.users u
    where u.id = new.auth_user_id
      and u.phone_confirmed_at is not null
      and public.normalize_tr_phone(u.phone) ~ '^905[0-9]{9}$'
      and public.normalize_tr_phone(u.phone) = public.normalize_tr_phone(new.phone)
  ) then
    raise exception 'The Auth phone does not match the contract';
  end if;
  return new;
end;
$$;

create trigger customer_validate_contract_auth_link
  before insert or update of auth_user_id, contract_number on public.customers
  for each row execute function public.validate_contract_auth_link();
revoke execute on function public.validate_contract_auth_link() from public, anon, authenticated;

alter policy "ticket_attachment_authorized_read" on storage.objects using (
  bucket_id = 'message-attachments' and exists (
    select 1 from public.ticket_messages m
      where m.attachment_object_path = storage.objects.name
        and m.ticket_id::text = split_part(storage.objects.name, '/', 1)
        and m.sender_id::text = split_part(storage.objects.name, '/', 2)
  )
);

alter policy "contract_staff_upload_private" on storage.objects with check (
  bucket_id = 'customer-contracts' and (select public.can_manage_finance())
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

alter policy "contract_staff_delete_unlinked_or_finance" on storage.objects using (
  bucket_id = 'customer-contracts' and (select public.can_manage_finance())
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not exists (select 1 from public.customer_contract_documents d
      where d.storage_path = storage.objects.name)
    and not exists (select 1 from public.pending_contract_records p
      where p.storage_path = storage.objects.name)
);

create index if not exists payment_submissions_receipt_path_idx
  on public.payment_submissions(receipt_object_path);
create index if not exists ticket_messages_attachment_path_idx
  on public.ticket_messages(attachment_object_path) where attachment_object_path is not null;

-- Disambiguate the contract counter column from the PL/pgSQL variable.
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
  v_contract_year integer;
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

  v_contract_year := extract(year from p_contract_date)::integer;
  insert into public.customer_contract_counters as counters (contract_year, last_number)
    values (v_contract_year, 1)
    on conflict (contract_year) do update set last_number = counters.last_number + 1
    returning last_number into serial_number;
  if serial_number > 999999 then
    raise exception 'The contract sequence for % is full', v_contract_year;
  end if;
  generated_contract_number := 'S/' || v_contract_year::text || lpad(serial_number::text, 6, '0');

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

-- Attach a pending contract to the existing account row. Keeping its ID also
-- keeps notes, receipts, messages, and their existing storage paths intact.
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
    folder_id = pending_contract.folder_id
    where id = account_customer.id;

  if pending_contract.storage_path is not null then
    insert into public.customer_contract_documents (
      customer_id, storage_path, file_name, content_type, uploaded_by
    ) values (
      account_customer.id, pending_contract.storage_path, pending_contract.file_name,
      pending_contract.content_type, pending_contract.uploaded_by
    );
  end if;
  delete from public.pending_contract_records where id = pending_contract.id;
  return account_customer.id;
end;
$$;

notify pgrst, 'reload schema';
