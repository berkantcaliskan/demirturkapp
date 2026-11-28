-- Auth Admin creates the row and writes app_metadata later in the SAME
-- transaction. Validate the committed row, rather than its INSERT snapshot.
create or replace function portal_private.validate_new_account()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists(select 1 from auth.users where id=new.id)
    and not exists(select 1 from auth.users where id=new.id
      and raw_app_meta_data->>'portal_registration' in ('customer_v1','staff_v1')) then
    raise exception 'Use the application registration service' using errcode='42501';
  end if;
  return new;
end $$;
drop trigger portal_validate_new_account on auth.users;
create constraint trigger portal_validate_new_account after insert on auth.users
deferrable initially deferred for each row execute function portal_private.validate_new_account();
