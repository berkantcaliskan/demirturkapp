-- Staff ID allocation is collision-safe and identifiers remain stable after
-- assignment, name edits, and later role changes.
create or replace function public.assign_staff_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  role_prefix text;
  id_prefix text;
  name_code text;
  candidate text;
  name_length integer;
  duplicate_number integer := 1;
begin
  if new.role <> 'admin'::public.app_role and new.staff_role is null then
    new.staff_id := null;
    return new;
  end if;

  if tg_op = 'UPDATE' and old.staff_id is not null then
    new.staff_id := old.staff_id;
    return new;
  end if;

  role_prefix := case new.staff_role
    when 'sales_advisor' then 'SD'
    when 'accounting' then 'M'
    else 'Y'
  end;
  id_prefix := role_prefix || pg_catalog.to_char(
    pg_catalog.timezone('Europe/Istanbul', pg_catalog.now()), 'YYYYMM'
  ) || '/';
  name_code := pg_catalog.regexp_replace(
    pg_catalog.translate(pg_catalog.upper(coalesce(new.full_name, '')),
      'ÇĞİÖŞÜ', 'CGIOSU'),
    '[^A-Z0-9]', '', 'g'
  );
  if name_code = '' then name_code := 'XXX'; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(id_prefix, 0)
  );

  name_length := least(3, pg_catalog.char_length(name_code));
  loop
    candidate := id_prefix || pg_catalog.substr(name_code, 1, name_length);
    exit when not exists (
      select 1 from public.profiles p where p.staff_id = candidate
    );
    if name_length < pg_catalog.char_length(name_code) then
      name_length := name_length + 1;
    else
      loop
        candidate := id_prefix || name_code || duplicate_number::text;
        exit when not exists (
          select 1 from public.profiles p where p.staff_id = candidate
        );
        duplicate_number := duplicate_number + 1;
      end loop;
      exit;
    end if;
  end loop;

  new.staff_id := candidate;
  return new;
end;
$$;

-- Only a sales advisor profile may be assigned to a customer.
create or replace function public.validate_customer_sales_advisor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.assigned_advisor_id is not null and not exists (
    select 1 from public.profiles p
    where p.id = new.assigned_advisor_id
      and p.staff_role = 'sales_advisor'
  ) then
    raise exception 'assigned_advisor_id must reference a sales advisor';
  end if;
  return new;
end;
$$;

drop trigger if exists customers_validate_sales_advisor on public.customers;
create trigger customers_validate_sales_advisor
  before insert or update of assigned_advisor_id on public.customers
  for each row execute function public.validate_customer_sales_advisor();

-- When management changes a customer's advisor, route every open advisor
-- conversation to the new advisor immediately. Ticket access policies use
-- assigned_staff_id, so this keeps both inbox routing and authorization in
-- sync with the customer record.
create or replace function public.sync_customer_advisor_tickets()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.assigned_advisor_id is distinct from old.assigned_advisor_id then
    update public.support_tickets t
    set assigned_staff_id = new.assigned_advisor_id,
        updated_at = pg_catalog.now()
    where t.customer_id = new.id
      and t.channel = 'advisor'
      and t.closed_at is null
      and t.assigned_staff_id is distinct from new.assigned_advisor_id;
  end if;
  return new;
end;
$$;

drop trigger if exists customers_sync_advisor_tickets on public.customers;
create trigger customers_sync_advisor_tickets
  after update of assigned_advisor_id on public.customers
  for each row execute function public.sync_customer_advisor_tickets();

revoke all on function public.assign_staff_id() from public, anon, authenticated;
revoke all on function public.validate_customer_sales_advisor() from public, anon, authenticated;
revoke all on function public.sync_customer_advisor_tickets() from public, anon, authenticated;

notify pgrst, 'reload schema';
