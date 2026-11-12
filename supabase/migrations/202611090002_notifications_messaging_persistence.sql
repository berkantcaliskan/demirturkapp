-- Durable notification delivery, device registrations, chat retention, and user settings.
create table public.push_devices (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web', 'windows', 'macos', 'linux', 'fuchsia')),
  updated_at timestamptz not null default now()
);
create index push_devices_user_idx on public.push_devices(user_id);
alter table public.push_devices enable row level security;
create policy "users_manage_own_push_devices" on public.push_devices for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant select, insert, update, delete on public.push_devices to authenticated;

-- One durable queue row per notification; configure a Supabase Database Webhook
-- on INSERT to invoke the send-push Edge Function (documented in README).
create table public.push_outbox (
  id bigint generated always as identity primary key,
  notification_id uuid references public.notifications(id) on delete set null,
  recipient_user_id uuid references auth.users(id) on delete cascade,
  send_to_admins boolean not null default false,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  attempts integer not null default 0,
  last_error text
);
create unique index push_outbox_notification_once on public.push_outbox(notification_id)
  where notification_id is not null;
alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from anon, authenticated;

create function public.enqueue_notification_push()
returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid;
begin
  select auth_user_id into recipient from public.customers where id = new.customer_id;
  if recipient is not null then
    insert into public.push_outbox(notification_id, recipient_user_id, title, body, data)
    values (new.id, recipient, new.title, new.body,
      jsonb_build_object('notification_id', new.id, 'type', new.type));
  end if;
  return new;
end;
$$;
create trigger notification_enqueue_push after insert on public.notifications
  for each row execute function public.enqueue_notification_push();

-- Customer-facing messages stay available until explicitly deleted. General
-- company chats close for that customer but remain in the admin archive.
alter table public.support_tickets
  add column if not exists closed_at timestamptz,
  add column if not exists hidden_for_customer_at timestamptz,
  add column if not exists deleted_at timestamptz;
alter table public.customers
  add column if not exists project_name text not null default '',
  add column if not exists unit_label text not null default '',
  add column if not exists project_status text not null default '';
create or replace function public.normalize_tr_phone(value text)
returns text language sql immutable set search_path = '' as $$
  select case
    when length(digits) = 10 then '90' || digits
    when length(digits) = 11 and left(digits, 1) = '0' then '90' || substr(digits, 2)
    else digits
  end
  from (select regexp_replace(coalesce(value, ''), '[^0-9]', '', 'g') as digits) normalized;
$$;
create index if not exists customers_unlinked_phone_digits_idx
  on public.customers (public.normalize_tr_phone(phone))
  where auth_user_id is null;

-- Link a verified signup to its pre-created customer contract by phone only
-- when exactly one unlinked customer has that normalized number.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare matches integer;
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), 'customer');

  if new.phone is not null and new.phone <> '' then
    select count(*) into matches
    from public.customers c
    where c.auth_user_id is null
      and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(new.phone);
    if matches = 1 then
      update public.customers c
      set auth_user_id = new.id
      where c.auth_user_id is null
        and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(new.phone);
    end if;
  end if;
  return new;
end;
$$;
alter table public.ticket_messages
  add column if not exists deleted_at timestamptz;
create index support_tickets_admin_archive_idx
  on public.support_tickets(channel, closed_at desc) where closed_at is not null;

drop policy if exists "tickets_read_linked_or_admin" on public.support_tickets;
create policy "tickets_read_visible_or_admin" on public.support_tickets for select to authenticated
  using (
    (select public.is_admin()) or
    (customer_id = (select public.current_customer_id())
      and hidden_for_customer_at is null and deleted_at is null)
  );

drop policy if exists "messages_read_ticket_member_or_admin" on public.ticket_messages;
create policy "messages_read_visible_ticket_member_or_admin" on public.ticket_messages for select to authenticated
  using (
    (select public.is_admin()) or exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and t.customer_id = (select public.current_customer_id())
        and t.hidden_for_customer_at is null and t.deleted_at is null
    )
  );
drop policy if exists "messages_sender_create" on public.ticket_messages;
create policy "messages_sender_create_open_ticket" on public.ticket_messages for insert to authenticated
  with check (
    sender_id = (select auth.uid()) and exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and (
        (select public.is_admin()) or
        (t.customer_id = (select public.current_customer_id())
          and t.hidden_for_customer_at is null and t.closed_at is null)
      )
    )
  );

create or replace function public.set_ticket_updated_at()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.support_tickets set updated_at = now() where id = new.ticket_id;
  return new;
end;
$$;
create trigger ticket_message_updates_ticket after insert on public.ticket_messages
  for each row execute function public.set_ticket_updated_at();

create or replace function public.notify_for_ticket_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare ticket public.support_tickets%rowtype;
begin
  select * into ticket from public.support_tickets where id = new.ticket_id;
  if exists (select 1 from public.customers where id = ticket.customer_id and auth_user_id = new.sender_id) then
    insert into public.push_outbox(send_to_admins, title, body, data)
    values (true, 'Yeni müşteri mesajı', left(new.body, 180),
      jsonb_build_object('ticket_id', ticket.id, 'type', 'message'));
  else
    insert into public.notifications(customer_id, title, body, type)
    values (ticket.customer_id, 'Yeni mesajınız var', left(new.body, 180), 'message');
  end if;
  return new;
end;
$$;
create trigger ticket_message_notifications after insert on public.ticket_messages
  for each row execute function public.notify_for_ticket_message();

create function public.notify_payment_submission_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare note_label text;
begin
  select note_number into note_label from public.promissory_notes where id = new.note_id;
  if tg_op = 'INSERT' then
    update public.promissory_notes set status = 'verifying' where id = new.note_id;
    insert into public.notifications(customer_id, title, body, type)
    values (new.customer_id, 'Dekontunuz alındı', 'Senet ' || note_label || ' için ödeme bildiriminiz inceleniyor.', 'receipt');
  elsif new.status is distinct from old.status then
    if new.status = 'approved' then
      update public.promissory_notes set status = 'paid', paid_at = coalesce(paid_at, now()) where id = new.note_id;
      insert into public.notifications(customer_id, title, body, type)
      values (new.customer_id, 'Ödemeniz onaylandı', 'Senet ' || note_label || ' ödemeniz onaylandı.', 'approved');
    elsif new.status = 'rejected' then
      update public.promissory_notes
      set status = case when due_date < current_date then 'overdue'::public.note_status else 'pending'::public.note_status end
      where id = new.note_id;
      insert into public.notifications(customer_id, title, body, type)
      values (new.customer_id, 'Dekontunuz incelendi', coalesce(new.rejection_reason, 'Lütfen dekontunuzu kontrol edin.'), 'rejected');
    end if;
  end if;
  return new;
end;
$$;
create trigger payment_submission_notifications after insert or update of status
  on public.payment_submissions for each row execute function public.notify_payment_submission_change();

-- Preferences are durable per account and isolated by RLS.
create table public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.user_preferences enable row level security;
create policy "users_manage_own_preferences" on public.user_preferences for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant select, insert, update, delete on public.user_preferences to authenticated;

-- Caller may close a general chat. Customer access hides it; administrators
-- retain it in the dated archive. Advisor/finance conversations are untouched.
create function public.close_general_chat(ticket_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.support_tickets
  set closed_at = now(), hidden_for_customer_at = now(), is_resolved = true, updated_at = now()
  where id = ticket_id and channel = 'general'
    and customer_id = (select public.current_customer_id()) and closed_at is null
    and channel = 'general';
  if not found then raise exception 'General chat not found or already closed'; end if;
end;
$$;
revoke all on function public.close_general_chat(uuid) from public, anon;
grant execute on function public.close_general_chat(uuid) to authenticated;

create function public.delete_my_chat(ticket_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.support_tickets
  where id = ticket_id and customer_id = (select public.current_customer_id())
    and channel in ('advisor', 'finance');
  if not found then raise exception 'Chat not found or cannot be deleted'; end if;
end;
$$;
revoke all on function public.delete_my_chat(uuid) from public, anon;
grant execute on function public.delete_my_chat(uuid) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-receipts', 'payment-receipts', false, 10485760,
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "receipt_owner_delete" on storage.objects for delete to authenticated
  using (
    bucket_id = 'payment-receipts' and
    (storage.foldername(name))[1] = (select public.current_customer_id())::text
  );

-- Realtime on message inserts lets open clients receive messages immediately.
do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ticket_messages'
  ) then alter publication supabase_realtime add table public.ticket_messages; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then alter publication supabase_realtime add table public.notifications; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'promissory_notes'
  ) then alter publication supabase_realtime add table public.promissory_notes; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'customers'
  ) then alter publication supabase_realtime add table public.customers; end if;
end $$;
