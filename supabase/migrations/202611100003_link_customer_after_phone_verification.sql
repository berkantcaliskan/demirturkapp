-- Only link a customer contract after Supabase Auth has verified the phone.
-- Auth inserts the user before the SMS OTP is confirmed, so linking from the
-- signup insert alone would let an unverified signup reserve a contract.

create or replace function public.handle_new_user()
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

create or replace function public.link_verified_customer_phone()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare matches integer;
begin
  if new.phone is null or new.phone = '' or new.phone_confirmed_at is null then
    return new;
  end if;

  -- A customer account can only own one contract. Do not attach a second one
  -- when an already-linked user changes their phone number.
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

drop trigger if exists link_verified_customer_after_insert on auth.users;
create trigger link_verified_customer_after_insert
  after insert on auth.users
  for each row execute function public.link_verified_customer_phone();

drop trigger if exists link_verified_customer_after_phone_change on auth.users;
create trigger link_verified_customer_after_phone_change
  after update of phone, phone_confirmed_at on auth.users
  for each row
  when (new.phone is distinct from old.phone
    or new.phone_confirmed_at is distinct from old.phone_confirmed_at)
  execute function public.link_verified_customer_phone();

revoke all on function public.link_verified_customer_phone() from public, anon, authenticated;
