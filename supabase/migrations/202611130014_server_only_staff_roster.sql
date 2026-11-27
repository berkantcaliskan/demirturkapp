-- Staff phone reservations and short-lived provisioning access stay on the
-- server. Neither roster phone numbers nor credentials are bundled in the app.
create table public.staff_account_roster (
  name text primary key,
  phone text not null unique check (phone ~ '^\+905[0-9]{9}$'),
  staff_role text not null check (staff_role in ('sales_advisor','accounting','management'))
);
alter table public.staff_account_roster enable row level security;
revoke all on public.staff_account_roster from public, anon, authenticated;
grant all on public.staff_account_roster to service_role;

create table public.staff_provisioning_access (
  key_hash text primary key check (key_hash ~ '^[a-f0-9]{64}$'),
  expires_at timestamptz not null
);
alter table public.staff_provisioning_access enable row level security;
revoke all on public.staff_provisioning_access from public, anon, authenticated;
grant all on public.staff_provisioning_access to service_role;

revoke all on function public.ensure_my_customer_record(text) from public, anon;
grant execute on function public.ensure_my_customer_record(text) to authenticated;
notify pgrst, 'reload schema';
