create table public.portal_account_action_log (
  id bigint generated always as identity primary key,
  actor_id uuid not null,
  account_id uuid not null,
  action text not null,
  resource_id uuid,
  created_at timestamptz not null default now()
);
alter table public.portal_account_action_log enable row level security;
revoke all on public.portal_account_action_log from public, anon, authenticated;
grant select on public.portal_account_action_log to service_role;

create function public.portal_delegation_target(p_account_id uuid)
returns public.profiles language plpgsql stable security definer set search_path = '' as $$
declare
  target public.profiles%rowtype;
begin
  if not public.is_portal_manager() or p_account_id = (select auth.uid()) then
    raise exception 'Delegated account access denied' using errcode = '42501';
  end if;
  select * into target from public.profiles where id = p_account_id;
  if not found then raise exception 'Account not found' using errcode = '42501'; end if;
  return target;
end;
$$;
revoke all on function public.portal_delegation_target(uuid) from public, anon, authenticated;

create function public.portal_delegation_ticket_visible(
  target public.profiles, ticket public.support_tickets
)
returns boolean language sql stable set search_path = '' as $$
  select coalesce(target.staff_role in ('accounting', 'management')
    or (target.role = 'admin' and target.staff_role is null), false)
    or coalesce(target.staff_role = 'sales_advisor' and (
      (ticket.channel = 'general' and ticket.is_quick_conversation)
      or (ticket.channel = 'advisor' and ticket.assigned_staff_id = target.id)
    ), false)
    or (target.role = 'customer' and target.staff_role is null
      and ticket.hidden_for_customer_at is null and ticket.deleted_at is null
      and exists (select 1 from public.customers c where c.id = ticket.customer_id and c.auth_user_id = target.id));
$$;
revoke all on function public.portal_delegation_ticket_visible(public.profiles, public.support_tickets)
  from public, anon, authenticated;

create function public.list_delegated_portal_tickets(p_account_id uuid)
returns table (id uuid, subject text, closed_at timestamptz, customer_name text)
language plpgsql stable security definer set search_path = '' as $$
declare
  target public.profiles := public.portal_delegation_target(p_account_id);
begin
  return query select t.id, t.subject, t.closed_at, c.full_name
    from public.support_tickets t join public.customers c on c.id = t.customer_id
    where public.portal_delegation_ticket_visible(target, t)
    order by t.updated_at desc, t.id;
end;
$$;
revoke all on function public.list_delegated_portal_tickets(uuid) from public, anon;
grant execute on function public.list_delegated_portal_tickets(uuid) to authenticated;

create function public.perform_portal_account_action(p_account_id uuid, p_action text, p_payload jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  target public.profiles := public.portal_delegation_target(p_account_id);
  finance boolean := coalesce(target.staff_role in ('accounting', 'management')
    or (target.role = 'admin' and target.staff_role is null), false);
  advisor boolean := coalesce(target.staff_role = 'sales_advisor', false);
  record_id uuid;
  selected_folder uuid;
  ticket public.support_tickets%rowtype;
  message_body text;
begin
  case p_action
    when 'create_folder' then
      if not (finance or advisor) then raise exception 'Folder access denied' using errcode = '42501'; end if;
      insert into public.customer_folders (name, created_by)
        values (btrim(p_payload->>'name'), target.id) returning id into record_id;
    when 'assign_folder' then
      record_id := (p_payload->>'customer_id')::uuid;
      selected_folder := (p_payload->>'folder_id')::uuid;
      if not exists (select 1 from public.customers c where c.id = record_id
        and (finance or (advisor and c.assigned_advisor_id = target.id))) then
        raise exception 'Customer folder assignment denied' using errcode = '42501';
      end if;
      if selected_folder is null then
        delete from public.customer_folder_memberships m where m.owner_id = target.id and m.customer_id = record_id;
      else
        if not exists (select 1 from public.customer_folders f where f.id = selected_folder and f.created_by = target.id) then
          raise exception 'Folder belongs to a different account' using errcode = '42501';
        end if;
        insert into public.customer_folder_memberships (owner_id, customer_id, folder_id)
          values (target.id, record_id, selected_folder)
          on conflict (owner_id, customer_id) do update set folder_id = excluded.folder_id;
      end if;
    when 'send_message' then
      message_body := btrim(coalesce(p_payload->>'body', ''));
      if char_length(message_body) not between 1 and 4000 then
        raise exception 'Message must contain 1–4000 characters';
      end if;
      select * into ticket from public.support_tickets t where t.id = (p_payload->>'ticket_id')::uuid for update;
      if not found or ticket.closed_at is not null or public.portal_delegation_ticket_visible(target, ticket) is not true then
        raise exception 'Conversation access denied' using errcode = '42501';
      end if;
      insert into public.ticket_messages (ticket_id, sender_id, body)
        values (ticket.id, target.id, message_body) returning id into record_id;
    when 'review_payment' then
      if not finance then raise exception 'Payment review denied' using errcode = '42501'; end if;
      if (p_payload->>'decision') is null or (p_payload->>'decision') not in ('approved', 'rejected') then
        raise exception 'Invalid payment decision';
      end if;
      update public.payment_submissions p
        set status = p_payload->>'decision',
            rejection_reason = case when p_payload->>'decision' = 'rejected' then nullif(btrim(p_payload->>'reason'), '') end
        where p.id = (p_payload->>'submission_id')::uuid and p.status = 'submitted'
        returning p.id into record_id;
      if not found then raise exception 'Receipt is no longer awaiting review'; end if;
    when 'link_contract' then
      if not finance then raise exception 'Contract approval denied' using errcode = '42501'; end if;
      if coalesce((p_payload->>'pending')::boolean, false) then
        record_id := public.link_pending_contract_account((p_payload->>'contract_id')::uuid, (p_payload->>'customer_id')::uuid);
      else
        record_id := public.link_customer_account((p_payload->>'contract_id')::uuid, (p_payload->>'customer_id')::uuid);
      end if;
    else
      raise exception 'Unsupported delegated action' using errcode = '42501';
  end case;
  insert into public.portal_account_action_log (actor_id, account_id, action, resource_id)
    values ((select auth.uid()), target.id, p_action, record_id);
  return record_id;
end;
$$;
revoke all on function public.perform_portal_account_action(uuid, text, jsonb) from public, anon;
grant execute on function public.perform_portal_account_action(uuid, text, jsonb) to authenticated;

notify pgrst, 'reload schema';
