-- Final contract format: S/{YYYY}{six-digit yearly sequence}.
-- Example: S/2026000001. The yearly counter is incremented atomically.

create table if not exists public.customer_contract_counters (
  contract_year integer primary key check (contract_year between 2000 and 9999),
  last_number integer not null check (last_number between 0 and 999999)
);
alter table public.customer_contract_counters enable row level security;
revoke all on public.customer_contract_counters from public, anon, authenticated;

-- If a matching-format contract was entered before this migration, continue
-- after its largest sequence rather than restarting at 000001.
insert into public.customer_contract_counters as counters (contract_year, last_number)
select (parts)[1]::integer, max((parts)[2]::integer)
from (
  select regexp_match(c.contract_number, '^S/([0-9]{4})([0-9]{6})$') as parts
  from public.customers c
  where c.contract_number ~ '^S/[0-9]{10}$'
) existing
group by (parts)[1]
on conflict (contract_year) do update
set last_number = greatest(
  counters.last_number,
  excluded.last_number
);

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
  contract_year integer;
  serial_number integer;
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

  return target_customer_id;
end;
$$;

revoke all on function public.create_customer_with_contract(text, text, text, uuid, date, uuid)
  from public, anon;
grant execute on function public.create_customer_with_contract(text, text, text, uuid, date, uuid)
  to authenticated;

notify pgrst, 'reload schema';
