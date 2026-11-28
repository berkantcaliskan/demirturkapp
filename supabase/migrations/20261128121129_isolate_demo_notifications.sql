create or replace function portal_private.skip_demo_notification()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists(select 1 from public.customers where id=new.customer_id and is_demo) then return null; end if;
  return new;
end $$;
revoke all on function portal_private.skip_demo_notification() from public,anon,authenticated;
create trigger portal_skip_demo_notification before insert on public.notifications
for each row execute function portal_private.skip_demo_notification();
