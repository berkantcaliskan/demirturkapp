-- Initial Demirtürk customer portal schema. Apply through Supabase migrations.
create extension if not exists pgcrypto;

create type public.app_role as enum ('customer', 'admin');
create type public.note_status as enum ('pending', 'verifying', 'paid', 'overdue');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.app_role not null default 'customer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  full_name text not null,
  national_or_tax_id text not null,
  phone text not null default '',
  email text not null default '',
  address text not null default '',
  contract_number text not null unique,
  assigned_advisor_name text,
  created_at timestamptz not null default now()
);

create table public.promissory_notes (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  note_number text not null unique,
  installment_index integer not null check (installment_index > 0),
  total_installments integer not null check (total_installments > 0),
  amount numeric(14,2) not null check (amount >= 0),
  due_date date not null,
  paid_at timestamptz,
  status public.note_status not null default 'pending',
  description text not null default '',
  payment_method text,
  created_at timestamptz not null default now(),
  check (installment_index <= total_installments)
);

create table public.payment_submissions (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.promissory_notes(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  receipt_object_path text not null,
  customer_note text,
  payment_method text not null,
  status text not null default 'submitted' check (status in ('submitted', 'approved', 'rejected')),
  rejection_reason text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id)
);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  subject text not null,
  category text not null,
  channel text not null default 'general' check (channel in ('advisor', 'finance', 'general')),
  related_note_id uuid references public.promissory_notes(id) on delete set null,
  is_resolved boolean not null default false,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text not null,
  attachment_object_path text,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  bank_name text not null,
  account_holder text not null,
  iban text not null,
  branch_name text not null default '',
  is_active boolean not null default true,
  sort_order integer not null default 0
);

create index promissory_notes_customer_due_idx on public.promissory_notes(customer_id, due_date);
create index payment_submissions_customer_idx on public.payment_submissions(customer_id, submitted_at desc);
create index support_tickets_customer_idx on public.support_tickets(customer_id, updated_at desc);
create index ticket_messages_ticket_idx on public.ticket_messages(ticket_id, created_at);
create index notifications_customer_idx on public.notifications(customer_id, created_at desc);

-- SECURITY DEFINER prevents RLS recursion when policies check the caller's role.
create function public.is_admin()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'::public.app_role
  );
$$;

create function public.current_customer_id()
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select c.id from public.customers c where c.auth_user_id = (select auth.uid()) limit 1;
$$;

-- New accounts get a customer profile. Admin accounts must be provisioned by a
-- trusted operator after signup; never accept a client-supplied role.
create function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), 'customer');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.promissory_notes enable row level security;
alter table public.payment_submissions enable row level security;
alter table public.support_tickets enable row level security;
alter table public.ticket_messages enable row level security;
alter table public.notifications enable row level security;
alter table public.bank_accounts enable row level security;

create policy "profiles_read_self_or_admin" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));
create policy "profiles_update_self_name_only" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()) and role = 'customer');

create policy "customers_read_linked_or_admin" on public.customers for select to authenticated
  using (auth_user_id = (select auth.uid()) or (select public.is_admin()));
create policy "customers_admin_write" on public.customers for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "notes_read_linked_or_admin" on public.promissory_notes for select to authenticated
  using (customer_id = (select public.current_customer_id()) or (select public.is_admin()));
create policy "notes_admin_write" on public.promissory_notes for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "payments_read_linked_or_admin" on public.payment_submissions for select to authenticated
  using (customer_id = (select public.current_customer_id()) or (select public.is_admin()));
create policy "payments_customer_submit" on public.payment_submissions for insert to authenticated
  with check (
    customer_id = (select public.current_customer_id())
    and exists (
      select 1 from public.promissory_notes n
      where n.id = note_id and n.customer_id = (select public.current_customer_id())
        and n.status in ('pending', 'overdue')
    )
  );
create policy "payments_admin_review" on public.payment_submissions for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "tickets_read_linked_or_admin" on public.support_tickets for select to authenticated
  using (customer_id = (select public.current_customer_id()) or (select public.is_admin()));
create policy "tickets_customer_create" on public.support_tickets for insert to authenticated
  with check (customer_id = (select public.current_customer_id()));
create policy "tickets_admin_write" on public.support_tickets for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy "messages_read_ticket_member_or_admin" on public.ticket_messages for select to authenticated
  using (
    (select public.is_admin()) or exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and t.customer_id = (select public.current_customer_id())
    )
  );
create policy "messages_sender_create" on public.ticket_messages for insert to authenticated
  with check (
    sender_id = (select auth.uid()) and exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and
        (t.customer_id = (select public.current_customer_id()) or (select public.is_admin()))
    )
  );

create policy "notifications_read_linked_or_admin" on public.notifications for select to authenticated
  using (customer_id = (select public.current_customer_id()) or (select public.is_admin()));
create policy "notifications_mark_own_read" on public.notifications for update to authenticated
  using (customer_id = (select public.current_customer_id()))
  with check (customer_id = (select public.current_customer_id()));
create policy "notifications_admin_write" on public.notifications for insert to authenticated
  with check ((select public.is_admin()));

create policy "bank_accounts_read_authenticated" on public.bank_accounts for select to authenticated
  using (is_active or (select public.is_admin()));
create policy "bank_accounts_admin_write" on public.bank_accounts for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

grant select on public.profiles, public.customers, public.promissory_notes,
  public.payment_submissions, public.support_tickets, public.ticket_messages,
  public.notifications, public.bank_accounts to authenticated;
grant update (full_name) on public.profiles to authenticated;
grant insert on public.payment_submissions, public.support_tickets, public.ticket_messages to authenticated;
grant update (status, rejection_reason, reviewed_at, reviewed_by) on public.payment_submissions to authenticated;
grant update (is_resolved, updated_at) on public.support_tickets to authenticated;
grant update (is_read) on public.notifications to authenticated;
grant insert, update, delete on public.customers, public.promissory_notes,
  public.notifications, public.bank_accounts to authenticated;
grant usage on type public.app_role, public.note_status to authenticated;
grant execute on function public.is_admin(), public.current_customer_id() to authenticated;

-- Create a private `payment-receipts` Storage bucket in the Supabase dashboard.
-- Object names must start with the linked customer UUID, e.g.
-- <customer-uuid>/<random-file-id>.pdf. These policies then isolate files.
create policy "receipt_owner_or_admin_read" on storage.objects for select to authenticated
  using (
    bucket_id = 'payment-receipts' and
    ((storage.foldername(name))[1] = (select public.current_customer_id())::text
      or (select public.is_admin()))
  );
create policy "receipt_owner_upload" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'payment-receipts' and
    (storage.foldername(name))[1] = (select public.current_customer_id())::text
  );
create policy "receipt_admin_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'payment-receipts' and (select public.is_admin()));
