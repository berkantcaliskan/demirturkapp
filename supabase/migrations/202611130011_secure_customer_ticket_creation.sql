-- Create customer support tickets through a trusted RPC so ownership is
-- derived from the authenticated session, never from client-supplied IDs.
create or replace function public.get_or_create_customer_ticket(p_channel text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid;
  v_assigned_advisor_id uuid;
  v_ticket_id uuid;
  v_ticket_subject text;
begin
  if (select auth.uid()) is null then
    raise exception 'An authenticated customer session is required';
  end if;
  if (select public.is_staff()) then
    raise exception 'Staff accounts cannot create customer tickets';
  end if;
  if p_channel is null or p_channel not in ('advisor', 'finance', 'general') then
    raise exception 'Unsupported support channel';
  end if;

  select c.id, c.assigned_advisor_id
    into v_customer_id, v_assigned_advisor_id
  from public.customers c
  where c.auth_user_id = (select auth.uid())
  limit 1;
  if v_customer_id is null then
    raise exception 'Hesabınız henüz müşteri kaydıyla eşleştirilmedi.';
  end if;
  if p_channel = 'advisor' and v_assigned_advisor_id is null then
    raise exception 'Satış danışmanınız henüz atanmamış.';
  end if;
  if p_channel = 'finance' and not exists (
    select 1 from public.profiles p where p.staff_role = 'accounting'
  ) then
    raise exception 'Muhasebe hesabı henüz tanımlanmamış.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_customer_id::text || ':' || p_channel, 0)
  );

  select t.id into v_ticket_id
  from public.support_tickets t
  where t.customer_id = v_customer_id
    and t.channel = p_channel
    and t.closed_at is null
    and t.deleted_at is null
    and t.hidden_for_customer_at is null
  order by t.updated_at desc
  limit 1;
  if v_ticket_id is not null then
    return v_ticket_id;
  end if;

  v_ticket_subject := case p_channel
    when 'advisor' then 'Satış danışmanı'
    when 'finance' then 'Muhasebe'
    else 'Şirket yetkilisi'
  end;

  insert into public.support_tickets (
    customer_id, subject, category, channel, is_quick_conversation
  ) values (
    v_customer_id, v_ticket_subject, p_channel, p_channel, p_channel = 'general'
  ) returning id into v_ticket_id;

  return v_ticket_id;
end;
$$;

revoke all on function public.get_or_create_customer_ticket(text)
  from public, anon;
grant execute on function public.get_or_create_customer_ticket(text)
  to authenticated;
