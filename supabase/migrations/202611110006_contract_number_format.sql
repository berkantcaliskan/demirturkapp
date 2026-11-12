-- Contract numbers use S/{sequence}{contract-date}{advisor-code}, e.g.
-- S/120261111E. The database issues the sequence and inserts atomically.

alter table public.profiles
  add column if not exists contract_code text;

with advisor_codes as (
  select
    p.id,
    coalesce(nullif(upper(left(btrim(p.full_name), 1)), ''), 'X') as base_code,
    row_number() over (
      partition by coalesce(nullif(upper(left(btrim(p.full_name), 1)), ''), 'X')
      order by p.created_at, p.id
    ) as code_index
  from public.profiles p
  where p.staff_role = 'sales_advisor' and p.contract_code is null
)
update public.profiles p
set contract_code = a.base_code || case when a.code_index = 1 then '' else a.code_index::text end
from advisor_codes a
where p.id = a.id;

create unique index if not exists profiles_sales_contract_code_unique
  on public.profiles (contract_code)
  where staff_role = 'sales_advisor' and contract_code is not null;

create or replace function public.assign_sales_contract_code()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  base_code text;
  candidate text;
  suffix integer := 1;
begin
  if new.staff_role is distinct from 'sales_advisor' then
    new.contract_code := null;
    return new;
  end if;
  if new.contract_code is not null and btrim(new.contract_code) <> '' then
    new.contract_code := upper(btrim(new.contract_code));
    return new;
  end if;

  base_code := coalesce(nullif(upper(left(btrim(new.full_name), 1)), ''), 'X');
  candidate := base_code;
  while exists (
    select 1 from public.profiles p
    where p.staff_role = 'sales_advisor'
      and p.contract_code = candidate
      and p.id is distinct from new.id
  ) loop
    suffix := suffix + 1;
    candidate := base_code || suffix::text;
  end loop;
  new.contract_code := candidate;
  return new;
end;
$$;

drop trigger if exists profiles_assign_sales_contract_code on public.profiles;
create trigger profiles_assign_sales_contract_code
  before insert or update of staff_role, full_name, contract_code
  on public.profiles for each row
  execute function public.assign_sales_contract_code();

create sequence if not exists public.customer_contract_number_seq
  as bigint start with 1 increment by 1 no cycle;

do $$
declare highest_existing bigint;
begin
  select max((regexp_match(c.contract_number, '^S/([0-9]+)[0-9]{8}[A-Z0-9]+$'))[1]::bigint)
    into highest_existing
  from public.customers c
  where c.contract_number ~ '^S/[0-9]+[0-9]{8}[A-Z0-9]+$';
  if highest_existing is null then
    perform setval('public.customer_contract_number_seq', 1, false);
  else
    perform setval('public.customer_contract_number_seq', highest_existing, true);
  end if;
end $$;

-- Do not let an Auth account promoted to staff later become auto-linked to a
-- customer record just because a phone number matches.
create or replace function public.link_verified_auth_user_for_customer()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  matched_user uuid;
  user_matches integer;
  customer_matches integer;
begin
  if new.auth_user_id is not null or new.phone is null or new.phone = '' then
    return new;
  end if;
  select count(*) into customer_matches from public.customers c
    where c.auth_user_id is null
      and public.normalize_tr_phone(c.phone) = public.normalize_tr_phone(new.phone);
  if customer_matches <> 1 then return new; end if;

  select count(*), min(u.id::text)::uuid into user_matches, matched_user
  from auth.users u
  join public.profiles p on p.id = u.id
  where u.phone_confirmed_at is not null
    and p.role <> 'admin'::public.app_role and p.staff_role is null
    and public.normalize_tr_phone(u.phone) = public.normalize_tr_phone(new.phone)
    and not exists (select 1 from public.customers linked where linked.auth_user_id = u.id);
  if user_matches = 1 then
    update public.customers set auth_user_id = matched_user
      where id = new.id and auth_user_id is null;
  end if;
  return new;
end;
$$;

create or replace function public.create_customer_with_contract(
  p_full_name text,
  p_national_or_tax_id text,
  p_phone text,
  p_assigned_advisor_id uuid,
  p_contract_date date,
  p_folder_id uuid default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  digits text;
  normalized_phone text;
  advisor_code text;
  serial_number bigint;
  generated_contract_number text;
  pending_count integer;
  target_customer_id uuid;
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

  select p.contract_code into advisor_code
  from public.profiles p
  where p.id = p_assigned_advisor_id and p.staff_role = 'sales_advisor';
  if advisor_code is null then
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

  serial_number := nextval('public.customer_contract_number_seq'::regclass);
  generated_contract_number := 'S/' || serial_number::text
    || to_char(p_contract_date, 'YYYYMMDD') || upper(advisor_code);

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

  return target_customer_id;
end;
$$;

revoke all on function public.assign_sales_contract_code() from public, anon, authenticated;
revoke all on function public.create_customer_with_contract(text, text, text, uuid, date, uuid)
  from public, anon;
grant execute on function public.create_customer_with_contract(text, text, text, uuid, date, uuid)
  to authenticated;

notify pgrst, 'reload schema';
