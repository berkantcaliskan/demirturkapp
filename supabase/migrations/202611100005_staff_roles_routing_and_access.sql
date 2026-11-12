-- Staff identity and permission tiers. `role=admin` is retained as the
-- historical full-access role; new staff use a customer Auth profile plus an
-- explicit staff_role set only by a trusted operator.
alter table public.profiles
  add column if not exists staff_role text
    check (staff_role in ('sales_advisor', 'accounting', 'management')),
  add column if not exists staff_id text unique,
  add column if not exists contact_phone text;

create unique index if not exists profiles_single_accounting_user
  on public.profiles (staff_role) where staff_role = 'accounting';

-- These columns must exist before the SQL-language access helper functions
-- below are parsed and validated by PostgreSQL.
alter table public.customers
  add column if not exists assigned_advisor_id uuid
    references public.profiles(id) on delete set null;
alter table public.support_tickets
  add column if not exists assigned_staff_id uuid
    references public.profiles(id) on delete set null,
  add column if not exists is_quick_conversation boolean not null default false;

create or replace function public.assign_staff_id()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.role = 'admin'::public.app_role or new.staff_role is not null then
    if new.staff_id is null or new.staff_id = '' then
      new.staff_id := 'DT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    end if;
  else
    new.staff_id := null;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_assign_staff_id on public.profiles;
create trigger profiles_assign_staff_id before insert or update of role, staff_role
  on public.profiles for each row execute function public.assign_staff_id();
update public.profiles set role = role
  where staff_id is null and (role = 'admin'::public.app_role or staff_role is not null);

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
      and (p.role = 'admin'::public.app_role or p.staff_role is not null)
  );
$$;

create or replace function public.is_sales_advisor()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
      and p.staff_role = 'sales_advisor'
  );
$$;

create or replace function public.can_manage_finance()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
      and (p.role = 'admin'::public.app_role or p.staff_role in ('accounting', 'management'))
  );
$$;

create or replace function public.can_access_customer(target_customer_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.customers c
    where c.id = target_customer_id
      and (
        c.auth_user_id = (select auth.uid())
        or (select public.can_manage_finance())
        or (c.assigned_advisor_id = (select auth.uid()) and (select public.is_sales_advisor()))
      )
  );
$$;

create or replace function public.can_access_ticket(target_ticket_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.support_tickets t
    where t.id = target_ticket_id and (
      (select public.can_manage_finance())
      or (t.customer_id = (select public.current_customer_id())
        and t.hidden_for_customer_at is null and t.deleted_at is null)
      or ((select public.is_sales_advisor()) and (
        (t.channel = 'general' and t.is_quick_conversation)
        or (t.channel = 'advisor' and t.assigned_staff_id = (select auth.uid()))
      ))
    )
  );
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.can_manage_finance();
$$;

-- Customers without a preloaded contract still receive a private, pending
-- customer row after phone verification and can enter the portal.
alter table public.customers
  alter column national_or_tax_id drop not null,
  alter column contract_number drop not null,
  add column if not exists assigned_advisor_id uuid references public.profiles(id) on delete set null,
  add column if not exists contract_status text not null default 'pending'
    check (contract_status in ('pending', 'approved', 'rejected')),
  add column if not exists folder_id uuid;
update public.customers set contract_status = 'approved'
  where contract_number is not null and contract_status = 'pending';
create index if not exists customers_assigned_advisor_idx
  on public.customers (assigned_advisor_id, created_at desc);

create table if not exists public.customer_folders (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
alter table public.customers drop constraint if exists customers_folder_id_fkey;
alter table public.customers add constraint customers_folder_id_fkey
  foreign key (folder_id) references public.customer_folders(id) on delete set null;
alter table public.customer_folders enable row level security;
grant select, insert, update, delete on public.customer_folders to authenticated;
create policy "staff_read_customer_folders" on public.customer_folders
  for select to authenticated using ((select public.is_staff()));
create policy "staff_manage_customer_folders" on public.customer_folders
  for all to authenticated using ((select public.is_staff()))
  with check ((select public.is_staff()));

alter table public.support_tickets
  add column if not exists assigned_staff_id uuid references public.profiles(id) on delete set null,
  add column if not exists is_quick_conversation boolean not null default false,
  add column if not exists answered_at timestamptz,
  add column if not exists answered_by uuid references public.profiles(id) on delete set null;
update public.support_tickets set is_quick_conversation = true
  where channel = 'general' and is_quick_conversation = false;
create index if not exists support_tickets_staff_inbox_idx
  on public.support_tickets (assigned_staff_id, channel, updated_at desc);
create index if not exists support_tickets_quick_inbox_idx
  on public.support_tickets (is_quick_conversation, updated_at desc)
  where is_quick_conversation;

create table if not exists public.staff_notifications (
  id uuid primary key default gen_random_uuid(),
  staff_user_id uuid not null references public.profiles(id) on delete cascade,
  ticket_id uuid references public.support_tickets(id) on delete cascade,
  message_id uuid references public.ticket_messages(id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  unique (staff_user_id, message_id)
);
create index if not exists staff_notifications_inbox_idx
  on public.staff_notifications (staff_user_id, created_at desc);
alter table public.staff_notifications enable row level security;
grant select, update on public.staff_notifications to authenticated;
create policy "staff_read_own_notifications" on public.staff_notifications
  for select to authenticated using (staff_user_id = (select auth.uid()));
create policy "staff_mark_own_notifications_read" on public.staff_notifications
  for update to authenticated using (staff_user_id = (select auth.uid()))
  with check (staff_user_id = (select auth.uid()));

-- Route direct messages at insertion time; quick conversations are broadcast
-- to the staff inbox and visually distinguishable from assigned DMs.
create or replace function public.route_customer_ticket()
returns trigger language plpgsql security definer set search_path = '' as $$
declare customer_row public.customers%rowtype;
begin
  select * into customer_row from public.customers where id = new.customer_id;
  if new.channel = 'advisor' and new.assigned_staff_id is null then
    new.assigned_staff_id := customer_row.assigned_advisor_id;
  elsif new.channel = 'finance' and new.assigned_staff_id is null then
    select p.id into new.assigned_staff_id from public.profiles p
      where p.staff_role = 'accounting' limit 1;
  elsif new.channel = 'general' then
    new.is_quick_conversation := true;
  end if;
  return new;
end;
$$;
drop trigger if exists support_tickets_route_staff on public.support_tickets;
create trigger support_tickets_route_staff before insert on public.support_tickets
  for each row execute function public.route_customer_ticket();
update public.support_tickets t set assigned_staff_id = c.assigned_advisor_id
  from public.customers c where t.customer_id = c.id and t.channel = 'advisor'
  and t.assigned_staff_id is null;
update public.support_tickets t set assigned_staff_id = p.id
  from public.profiles p where p.staff_role = 'accounting' and t.channel = 'finance'
  and t.assigned_staff_id is null;

-- Phone confirmation may link exactly one matching preloaded contract. A
-- pending shell is created only by ensure_my_customer_record() from the
-- customer app, after checking the signed-in account is not staff.
create or replace function public.link_verified_customer_phone()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  matches integer;
begin
  if new.phone is null or new.phone = '' or new.phone_confirmed_at is null then
    return new;
  end if;
  if exists (select 1 from public.profiles p where p.id = new.id and p.staff_role is not null) then
    return new;
  end if;
  if exists (select 1 from public.customers c where c.auth_user_id = new.id) then
    return new;
  end if;

  select count(*) into matches from public.customers c
  where c.auth_user_id is null
    and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(new.phone);
  if matches = 1 then
    update public.customers c set auth_user_id = new.id
    where c.auth_user_id is null
      and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(new.phone);
  end if;
  return new;
end;
$$;
drop trigger if exists link_verified_customer_after_insert on auth.users;
-- Staff accounts are manually created in Auth. Do not turn those auth.users
-- rows into customer records automatically; customer shells are created by
-- ensure_my_customer_record() when the verified user enters the customer app.
drop trigger if exists link_verified_customer_after_phone_change on auth.users;
create trigger link_verified_customer_after_phone_change
  after update of phone, phone_confirmed_at on auth.users
  for each row when (new.phone is distinct from old.phone
    or new.phone_confirmed_at is distinct from old.phone_confirmed_at)
  execute function public.link_verified_customer_phone();

create or replace function public.ensure_my_customer_record(p_full_name text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  user_row auth.users%rowtype;
  matches integer;
  customer_id uuid;
begin
  select * into user_row from auth.users u
    where u.id = (select auth.uid()) and u.phone_confirmed_at is not null;
  if user_row.id is null then
    raise exception 'A verified phone session is required';
  end if;
  if exists (select 1 from public.profiles p
      where p.id = user_row.id and p.staff_role is not null) then
    raise exception 'Staff accounts cannot create customer records';
  end if;
  select c.id into customer_id from public.customers c
    where c.auth_user_id = user_row.id limit 1;
  if customer_id is not null then return customer_id; end if;

  select count(*) into matches from public.customers c
    where c.auth_user_id is null
      and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(user_row.phone);
  if matches = 1 then
    update public.customers c set auth_user_id = user_row.id
      where c.auth_user_id is null
        and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(user_row.phone)
      returning c.id into customer_id;
  elsif matches > 1 then
    raise exception 'More than one customer record uses this phone number';
  else
    insert into public.customers (
      auth_user_id, full_name, national_or_tax_id, phone, email, address,
      contract_number, contract_status
    ) values (
      user_row.id,
      coalesce(nullif(btrim(p_full_name), ''), user_row.raw_user_meta_data ->> 'full_name', 'Müşteri'),
      null, user_row.phone, '', '', null, 'pending'
    ) returning id into customer_id;
  end if;
  return customer_id;
end;
$$;
grant execute on function public.ensure_my_customer_record(text) to authenticated;

-- Role-safe RLS. Every message inherits its parent ticket's exact customer
-- boundary; another customer can never read a ticket by guessing its ID.
drop policy if exists "profiles_read_self_or_admin" on public.profiles;
create policy "profiles_read_private_staff_directory" on public.profiles
  for select to authenticated using (
    id = (select auth.uid()) or (select public.is_staff())
    or exists (select 1 from public.customers c
      where c.auth_user_id = (select auth.uid()) and c.assigned_advisor_id = profiles.id)
  );
drop policy if exists "profiles_update_self_name_only" on public.profiles;

drop policy if exists "customers_read_linked_or_admin" on public.customers;
create policy "customers_read_scoped" on public.customers for select to authenticated
  using ((select public.can_access_customer(id)));
drop policy if exists "customers_admin_write" on public.customers;
create policy "customers_full_staff_write" on public.customers for all to authenticated
  using ((select public.can_manage_finance())) with check ((select public.can_manage_finance()));
create policy "sales_update_assigned_customer" on public.customers for update to authenticated
  using ((select public.is_sales_advisor()) and assigned_advisor_id = (select auth.uid()))
  with check ((select public.is_sales_advisor()) and assigned_advisor_id = (select auth.uid()));

drop policy if exists "notes_read_linked_or_admin" on public.promissory_notes;
drop policy if exists "notes_admin_write" on public.promissory_notes;
create policy "notes_customer_or_finance_read" on public.promissory_notes for select to authenticated
  using (customer_id = (select public.current_customer_id()) or (select public.can_manage_finance()));
create policy "notes_finance_write" on public.promissory_notes for all to authenticated
  using ((select public.can_manage_finance())) with check ((select public.can_manage_finance()));

drop policy if exists "payments_read_linked_or_admin" on public.payment_submissions;
drop policy if exists "payments_admin_review" on public.payment_submissions;
create policy "payments_customer_or_finance_read" on public.payment_submissions for select to authenticated
  using (customer_id = (select public.current_customer_id()) or (select public.can_manage_finance()));
create policy "payments_finance_review" on public.payment_submissions for update to authenticated
  using ((select public.can_manage_finance())) with check ((select public.can_manage_finance()));

drop policy if exists "tickets_read_visible_or_admin" on public.support_tickets;
drop policy if exists "tickets_read_linked_or_admin" on public.support_tickets;
drop policy if exists "tickets_customer_create" on public.support_tickets;
drop policy if exists "tickets_admin_write" on public.support_tickets;
create policy "tickets_read_role_scoped" on public.support_tickets for select to authenticated
  using ((select public.can_access_ticket(id)));
create policy "tickets_customer_create_own" on public.support_tickets for insert to authenticated
  with check (customer_id = (select public.current_customer_id()));
create policy "tickets_staff_update_scoped" on public.support_tickets for update to authenticated
  using ((select public.can_access_ticket(id)))
  with check ((select public.can_access_ticket(id)));

drop policy if exists "messages_read_visible_ticket_member_or_admin" on public.ticket_messages;
drop policy if exists "messages_read_ticket_member_or_admin" on public.ticket_messages;
drop policy if exists "messages_sender_create_open_ticket" on public.ticket_messages;
drop policy if exists "messages_sender_create" on public.ticket_messages;
create policy "messages_read_ticket_scope" on public.ticket_messages for select to authenticated
  using ((select public.can_access_ticket(ticket_id)));
create policy "messages_create_ticket_scope" on public.ticket_messages for insert to authenticated
  with check (sender_id = (select auth.uid()) and exists (
    select 1 from public.support_tickets t where t.id = ticket_id
      and (select public.can_access_ticket(t.id))
      and t.closed_at is null
  ));

-- Ensure only the assigned advisor sees the advisor DM. Finance and management
-- chats remain exclusive to their designated department and full managers.
create or replace function public.can_access_ticket(target_ticket_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.support_tickets t
    where t.id = target_ticket_id and (
      (select public.can_manage_finance())
      or (t.customer_id = (select public.current_customer_id())
        and t.hidden_for_customer_at is null and t.deleted_at is null)
      or ((select public.is_sales_advisor()) and (
        (t.channel = 'general' and t.is_quick_conversation)
        or (t.channel = 'advisor' and t.assigned_staff_id = (select auth.uid()))
      ))
      or (t.channel = 'finance' and t.assigned_staff_id = (select auth.uid())
        and exists (select 1 from public.profiles p where p.id = (select auth.uid())
          and p.staff_role = 'accounting'))
    )
  );
$$;

grant select, insert, update, delete on public.customer_folders to authenticated;
grant select, update on public.staff_notifications to authenticated;
grant execute on function public.is_staff(), public.is_sales_advisor(),
  public.can_manage_finance(), public.can_access_customer(uuid),
  public.can_access_ticket(uuid) to authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public'
        and tablename = 'support_tickets') then
    alter publication supabase_realtime add table public.support_tickets;
  end if;
  if not exists (select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public'
        and tablename = 'staff_notifications') then
    alter publication supabase_realtime add table public.staff_notifications;
  end if;
end $$;

-- Staff-targeted realtime notifications and customer quick-chat answered alert.
create or replace function public.notify_for_ticket_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  ticket public.support_tickets%rowtype;
  recipient record;
  is_customer boolean;
  notification_title text;
begin
  select * into ticket from public.support_tickets where id = new.ticket_id;
  select exists (select 1 from public.customers c
    where c.id = ticket.customer_id and c.auth_user_id = new.sender_id) into is_customer;

  if is_customer then
    if ticket.channel = 'advisor' and ticket.assigned_staff_id is not null then
      insert into public.staff_notifications(staff_user_id, ticket_id, message_id, title, body)
      values (ticket.assigned_staff_id, ticket.id, new.id, 'Yeni mesaj müşterinizden geldi', left(new.body, 180));
      insert into public.push_outbox(recipient_user_id, title, body, data)
      values (ticket.assigned_staff_id, 'Yeni müşteri mesajı', left(new.body, 180),
        jsonb_build_object('ticket_id', ticket.id, 'type', 'message'));
    elsif ticket.channel = 'finance' and ticket.assigned_staff_id is not null then
      insert into public.staff_notifications(staff_user_id, ticket_id, message_id, title, body)
      values (ticket.assigned_staff_id, ticket.id, new.id, 'Yeni muhasebe mesajı', left(new.body, 180));
      insert into public.push_outbox(recipient_user_id, title, body, data)
      values (ticket.assigned_staff_id, 'Yeni muhasebe mesajı', left(new.body, 180),
        jsonb_build_object('ticket_id', ticket.id, 'type', 'message'));
    else
      for recipient in select p.id from public.profiles p
        where p.role = 'admin'::public.app_role
          or p.staff_role in ('sales_advisor', 'accounting', 'management')
      loop
        insert into public.staff_notifications(staff_user_id, ticket_id, message_id, title, body)
        values (recipient.id, ticket.id, new.id, 'Hızlı görüşme', left(new.body, 180));
        insert into public.push_outbox(recipient_user_id, title, body, data)
        values (recipient.id, 'Yeni hızlı görüşme', left(new.body, 180),
          jsonb_build_object('ticket_id', ticket.id, 'type', 'quick_conversation'));
      end loop;
    end if;
  else
    if ticket.is_quick_conversation and ticket.answered_at is null then
      update public.support_tickets set answered_at = now(), answered_by = new.sender_id
        where id = ticket.id;
      notification_title := 'Bir yetkili yanıtladı';
    else
      notification_title := 'Yeni mesajınız var';
    end if;
    insert into public.notifications(customer_id, title, body, type)
    values (ticket.customer_id, notification_title, left(new.body, 180),
      case when ticket.is_quick_conversation then 'quick_answer' else 'message' end);
  end if;
  return new;
end;
$$;

-- Migrate existing direct conversations to their assigned employee.
update public.customers c set assigned_advisor_id = p.id
from public.profiles p where c.assigned_advisor_id is null
  and p.staff_role = 'sales_advisor' and c.assigned_advisor_name = p.full_name
  and (select count(*) from public.profiles p2
    where p2.staff_role = 'sales_advisor'
      and p2.full_name = c.assigned_advisor_name) = 1;

revoke all on function public.assign_staff_id(), public.route_customer_ticket()
  from public, anon, authenticated;
