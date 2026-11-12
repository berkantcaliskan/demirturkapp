-- Role-based staff IDs, unique per role and generated from the staff name.
-- Examples: SD202611/ERT, M202611/OZL, Y202611/BER.
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

  -- Serialize allocation within a role/month so concurrent signups cannot
  -- receive the same candidate before the unique index checks it.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(id_prefix, 0)
  );

  name_length := least(3, pg_catalog.char_length(name_code));
  loop
    candidate := id_prefix || pg_catalog.substr(name_code, 1, name_length);
    exit when not exists (
      select 1 from public.profiles p
      where p.staff_id = candidate and p.id is distinct from new.id
    );
    if name_length < pg_catalog.char_length(name_code) then
      name_length := name_length + 1;
    else
      loop
        candidate := id_prefix || name_code || duplicate_number::text;
        exit when not exists (
          select 1 from public.profiles p
          where p.staff_id = candidate and p.id is distinct from new.id
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

drop trigger if exists profiles_assign_staff_id on public.profiles;
create trigger profiles_assign_staff_id
  before insert or update of role, staff_role, full_name
  on public.profiles for each row execute function public.assign_staff_id();

-- Rebuild existing staff IDs in place using the same collision-safe allocator.
update public.profiles
set staff_id = null, role = role
where role = 'admin'::public.app_role or staff_role is not null;

revoke all on function public.assign_staff_id() from public, anon, authenticated;
notify pgrst, 'reload schema';
