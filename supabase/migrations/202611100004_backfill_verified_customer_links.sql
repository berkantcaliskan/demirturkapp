-- Backfill verified users that signed up before migration 003 was installed,
-- and link future customer rows created after the customer has signed up.
-- Matching is phone-only, normalized for Turkish number formats, and proceeds
-- only when exactly one unlinked customer and one eligible Auth user match.

create or replace function public.link_customer_for_verified_auth_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  matches integer;
begin
  if new.phone is null or new.phone = '' or new.phone_confirmed_at is null then
    return new;
  end if;

  if exists (
    select 1 from public.profiles p
    where p.id = new.id and p.role = 'admin'::public.app_role
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.customers c where c.auth_user_id = new.id
  ) then
    return new;
  end if;

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
  return new;
end;
$$;

create or replace function public.link_verified_auth_user_for_customer()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  matched_user uuid;
  user_matches integer;
  customer_matches integer;
begin
  if new.auth_user_id is not null or new.phone is null or new.phone = '' then
    return new;
  end if;

  select count(*) into customer_matches
  from public.customers c
  where c.auth_user_id is null
    and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(new.phone);

  if customer_matches <> 1 then
    return new;
  end if;

  select count(*), min(u.id::text)::uuid into user_matches, matched_user
  from auth.users u
  where u.phone_confirmed_at is not null
    and public.normalize_tr_phone(u.phone) = public.normalize_tr_phone(new.phone)
    and not exists (
      select 1 from public.profiles p
      where p.id = u.id and p.role = 'admin'::public.app_role
    )
    and not exists (
      select 1 from public.customers linked where linked.auth_user_id = u.id
    );

  if user_matches = 1 then
    update public.customers
    set auth_user_id = matched_user
    where id = new.id and auth_user_id is null;
  end if;
  return new;
end;
$$;

drop trigger if exists link_verified_customer_after_insert on auth.users;
create trigger link_verified_customer_after_insert
  after insert on auth.users
  for each row execute function public.link_customer_for_verified_auth_user();

drop trigger if exists link_verified_customer_after_phone_change on auth.users;
create trigger link_verified_customer_after_phone_change
  after update of phone, phone_confirmed_at on auth.users
  for each row
  when (new.phone is distinct from old.phone
    or new.phone_confirmed_at is distinct from old.phone_confirmed_at)
  execute function public.link_customer_for_verified_auth_user();

drop trigger if exists link_verified_user_after_customer_insert on public.customers;
create trigger link_verified_user_after_customer_insert
  after insert on public.customers
  for each row execute function public.link_verified_auth_user_for_customer();

drop trigger if exists link_verified_user_after_customer_phone_change on public.customers;
create trigger link_verified_user_after_customer_phone_change
  after update of phone on public.customers
  for each row
  when (new.phone is distinct from old.phone)
  execute function public.link_verified_auth_user_for_customer();

-- Attach existing verified accounts to exactly one pre-existing customer row.
update public.customers c
set auth_user_id = u.id
from auth.users u
where c.auth_user_id is null
  and u.phone_confirmed_at is not null
  and not exists (
    select 1 from public.profiles p
    where p.id = u.id and p.role = 'admin'::public.app_role
  )
  and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(u.phone)
  and (
    select count(*) from public.customers c2
    where c2.auth_user_id is null
      and public.normalize_tr_phone(c2.phone) = public.normalize_tr_phone(u.phone)
  ) = 1
  and (
    select count(*) from auth.users u2
    where u2.phone_confirmed_at is not null
      and not exists (
        select 1 from public.profiles p
        where p.id = u2.id and p.role = 'admin'::public.app_role
      )
      and public.normalize_tr_phone(u2.phone) = public.normalize_tr_phone(c.phone)
      and not exists (
        select 1 from public.customers linked where linked.auth_user_id = u2.id
      )
  ) = 1;

revoke all on function public.link_customer_for_verified_auth_user()
  from public, anon, authenticated;
revoke all on function public.link_verified_auth_user_for_customer()
  from public, anon, authenticated;
