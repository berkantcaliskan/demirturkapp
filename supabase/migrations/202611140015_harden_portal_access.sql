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
  if tg_op = 'UPDATE' and old.auth_user_id is not distinct from new.auth_user_id then
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
  before insert or update of auth_user_id on public.customers
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

notify pgrst, 'reload schema';
