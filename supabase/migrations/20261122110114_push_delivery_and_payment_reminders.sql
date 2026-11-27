alter table public.notifications
  add column data jsonb not null default '{}'::jsonb,
  add column event_key text unique;
alter table public.staff_notifications add column data jsonb not null default '{}'::jsonb;
alter table public.push_outbox
  add column locked_until timestamptz,
  add column next_attempt_at timestamptz not null default now(),
  add column expires_at timestamptz;
update public.push_outbox set expires_at = created_at + interval '1 day';
alter table public.push_outbox alter column expires_at set default (now() + interval '1 day');
alter table public.push_outbox alter column expires_at set not null;
create index push_outbox_pending_idx on public.push_outbox(next_attempt_at, id) where delivered_at is null;

create table public.push_deliveries (
  outbox_id bigint not null references public.push_outbox(id) on delete cascade,
  token text not null,
  delivered_at timestamptz not null default now(),
  primary key(outbox_id, token)
);
alter table public.push_deliveries enable row level security;
revoke all on public.push_deliveries from public, anon, authenticated;
grant all on public.push_deliveries to service_role;
grant all on public.push_outbox to service_role;

revoke insert, update on public.push_devices from authenticated;
create function public.register_push_device(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'Sign in required' using errcode = '42501'; end if;
  if length(p_token) not between 20 and 4096 or p_platform not in ('android','ios','web') then
    raise exception 'Invalid device registration';
  end if;
  insert into public.push_devices(token,user_id,platform,updated_at)
    values(p_token,(select auth.uid()),p_platform,now())
    on conflict(token) do update set user_id=excluded.user_id,platform=excluded.platform,updated_at=excluded.updated_at;
end;
$$;
revoke all on function public.register_push_device(text,text) from public,anon;
grant execute on function public.register_push_device(text,text) to authenticated;

create function public.claim_push_delivery(p_outbox_id bigint default null)
returns setof public.push_outbox language sql security definer set search_path = '' as $$
  update public.push_outbox q set locked_until=now()+interval '3 minutes',attempts=q.attempts+1
  where q.id=(select p.id from public.push_outbox p
    where (p_outbox_id is null or p.id=p_outbox_id) and p.delivered_at is null
      and p.expires_at>now() and p.attempts<8 and p.next_attempt_at<=now()
      and (p.locked_until is null or p.locked_until<now())
    order by p.next_attempt_at,p.id for update skip locked limit 1)
  returning q.*;
$$;
revoke all on function public.claim_push_delivery(bigint) from public,anon,authenticated;
grant execute on function public.claim_push_delivery(bigint) to service_role;

create or replace function public.enqueue_notification_push()
returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid;
begin
  select c.auth_user_id into recipient from public.customers c where c.id=new.customer_id;
  if recipient is not null then
    insert into public.push_outbox(notification_id,recipient_user_id,title,body,data)
      values(new.id,recipient,new.title,new.body,
        new.data || jsonb_build_object('notification_id',new.id,'type',new.type));
  end if;
  return new;
end;
$$;

create function public.enqueue_staff_notification_push()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.push_outbox(recipient_user_id,title,body,data)
    values(new.staff_user_id,new.title,new.body,
      new.data || jsonb_build_object('staff_notification_id',new.id,'ticket_id',new.ticket_id,
        'type',coalesce(new.data->>'type','message')));
  return new;
end;
$$;
revoke all on function public.enqueue_staff_notification_push() from public,anon,authenticated;
create trigger staff_notification_enqueue_push after insert on public.staff_notifications
  for each row execute function public.enqueue_staff_notification_push();

create or replace function public.notify_for_ticket_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  ticket public.support_tickets%rowtype;
  recipient record;
  customer_sender boolean;
begin
  select * into ticket from public.support_tickets where id=new.ticket_id;
  select exists(select 1 from public.customers c where c.id=ticket.customer_id and c.auth_user_id=new.sender_id)
    into customer_sender;
  if customer_sender then
    for recipient in select p.id from public.profiles p
      where (ticket.channel in ('advisor','finance') and p.id=ticket.assigned_staff_id)
        or (ticket.channel='general' and (p.staff_role in ('sales_advisor','accounting','management') or p.role='admin'))
    loop
      insert into public.staff_notifications(staff_user_id,ticket_id,message_id,title,body,data)
        values(recipient.id,ticket.id,new.id,'Yeni müşteri mesajı','Müşterinizden yeni bir mesaj var.',
          jsonb_build_object('type','message','ticket_id',ticket.id));
    end loop;
  else
    update public.support_tickets set answered_at=now(),answered_by=new.sender_id where id=ticket.id;
    insert into public.notifications(customer_id,title,body,type,data)
      values(ticket.customer_id,'Yeni mesajınız var','Demirtürk ekibinden yeni bir mesaj aldınız.','message',
        jsonb_build_object('ticket_id',ticket.id));
  end if;
  return new;
end;
$$;

create function public.notify_contract_approval()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.auth_user_id is null or new.contract_number is null or new.contract_status<>'approved' then return new; end if;
  if tg_op='UPDATE' and old.auth_user_id is not distinct from new.auth_user_id
    and old.contract_number is not distinct from new.contract_number and old.contract_status='approved' then return new; end if;
  insert into public.notifications(customer_id,title,body,type,data,event_key)
    values(new.id,'Sözleşmeniz onaylandı','Şimdi proje ve ödemelerinizi inceleyebilirsiniz.','contract',
      jsonb_build_object('customer_id',new.id), 'contract:'||new.auth_user_id::text||':'||new.contract_number)
    on conflict(event_key) do nothing;
  return new;
end;
$$;
revoke all on function public.notify_contract_approval() from public,anon,authenticated;
create trigger customer_contract_approval_notification after insert or update of auth_user_id,contract_number,contract_status
  on public.customers for each row execute function public.notify_contract_approval();

create function public.enqueue_due_payment_reminders(p_today date default (now() at time zone 'Europe/Istanbul')::date)
returns integer language plpgsql security definer set search_path = '' as $$
declare inserted integer;
begin
  insert into public.notifications(customer_id,title,body,type,data,event_key)
  select n.customer_id,
    case n.due_date-p_today when 2 then 'Ödemeniz yaklaşıyor' when 0 then 'Bugün ödeme gününüz' else 'Ödemeniz gecikti' end,
    case n.due_date-p_today
      when 2 then 'Son ödeme tarihiniz '||to_char(n.due_date,'DD.MM.YYYY')||'. Ödemenize 2 gün kaldı.'
      when 0 then to_char(n.due_date,'DD.MM.YYYY')||' tarihli ödemenizin son günü bugün.'
      else to_char(n.due_date,'DD.MM.YYYY')||' tarihli ödemeniz 2 gün gecikti. Ödeme durumunuzu inceleyebilirsiniz.' end,
    'reminder',jsonb_build_object('note_id',n.id,'due_date',n.due_date,'customer_id',n.customer_id),
    'payment:'||n.id::text||':'||n.due_date::text||':'||(n.due_date-p_today)::text
  from public.promissory_notes n join public.customers c on c.id=n.customer_id
  where n.status in ('pending','overdue') and c.auth_user_id is not null and c.contract_status='approved'
    and n.due_date in (p_today+2,p_today,p_today-2)
    and not exists(select 1 from public.payment_submissions s where s.note_id=n.id and s.status='submitted')
  on conflict(event_key) do nothing;
  get diagnostics inserted=row_count;
  return inserted;
end;
$$;
revoke all on function public.enqueue_due_payment_reminders(date) from public,anon,authenticated;
grant execute on function public.enqueue_due_payment_reminders(date) to service_role;

create function public.notify_staff_receipt()
returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient record;
begin
  for recipient in select p.id from public.profiles p
    where p.staff_role in ('accounting','management') or (p.role='admin' and p.staff_role is null)
  loop
    insert into public.staff_notifications(staff_user_id,title,body,data)
      values(recipient.id,'İncelenecek dekont var','Yeni bir ödeme bildirimi incelemenizi bekliyor.',
        jsonb_build_object('type','receipt','note_id',new.note_id));
  end loop;
  return new;
end;
$$;
revoke all on function public.notify_staff_receipt() from public,anon,authenticated;
create trigger payment_notify_staff after insert on public.payment_submissions
  for each row execute function public.notify_staff_receipt();

notify pgrst,'reload schema';

-- Only the trusted delivery worker can exchange its hook secret for FCM credentials.
create function public.push_worker_configuration(p_secret text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare expected text; credentials text;
begin
  if p_secret is null or length(p_secret)<64 then return null; end if;
  select decrypted_secret into expected from vault.decrypted_secrets where name='portal_push_webhook_secret';
  if expected is null or expected<>p_secret then return null; end if;
  select decrypted_secret into credentials from vault.decrypted_secrets where name='portal_fcm_service_account';
  return jsonb_build_object('service_account',credentials::jsonb);
end;
$$;
revoke all on function public.push_worker_configuration(text) from public,anon,authenticated;
grant execute on function public.push_worker_configuration(text) to service_role;

create function public.wake_push_dispatcher()
returns bigint language plpgsql security definer set search_path = '' as $$
declare endpoint text; hook text; request_id bigint;
begin
  if to_regclass('vault.decrypted_secrets') is null or to_regnamespace('net') is null then return null; end if;
  select decrypted_secret into endpoint from vault.decrypted_secrets where name='portal_push_endpoint';
  select decrypted_secret into hook from vault.decrypted_secrets where name='portal_push_webhook_secret';
  if endpoint is null or hook is null or not exists(
    select 1 from vault.decrypted_secrets where name='portal_fcm_service_account'
  ) then return null; end if;
  execute 'select net.http_post(url := $1, headers := $2, body := $3, timeout_milliseconds := 10000)'
    into request_id using endpoint,
      jsonb_build_object('Content-Type','application/json','x-webhook-secret',hook),'{}'::jsonb;
  return request_id;
exception when others then
  raise warning 'Push wakeup deferred to the retry job';
  return null;
end;
$$;
revoke all on function public.wake_push_dispatcher() from public,anon,authenticated;
grant execute on function public.wake_push_dispatcher() to service_role;

create function public.wake_push_on_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin perform public.wake_push_dispatcher(); return new; end;
$$;
revoke all on function public.wake_push_on_insert() from public,anon,authenticated;
create trigger push_outbox_dispatch after insert on public.push_outbox
  for each row execute function public.wake_push_on_insert();

do $$
begin
  if exists(select 1 from pg_available_extensions where name='pg_net') then
    execute 'create extension if not exists pg_net with schema extensions';
  end if;
  if exists(select 1 from pg_available_extensions where name='pg_cron') then
    execute 'create extension if not exists pg_cron';
    execute $job$select cron.schedule('demirturk-push-retry','* * * * *','select public.wake_push_dispatcher();')$job$;
    -- 07:00 UTC is 10:00 in Europe/Istanbul.
    execute $job$select cron.schedule('demirturk-payment-reminders','0 7 * * *','select public.enqueue_due_payment_reminders();')$job$;
  end if;
  if to_regclass('vault.secrets') is not null then
    if not exists(select 1 from vault.secrets where name='portal_push_webhook_secret') then
      perform vault.create_secret(replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''),'portal_push_webhook_secret');
    end if;
    if not exists(select 1 from vault.secrets where name='portal_push_endpoint') then
      perform vault.create_secret('https://twxkpypwagchnymeplxn.supabase.co/functions/v1/send-push','portal_push_endpoint');
    end if;
  end if;
end;
$$;

notify pgrst,'reload schema';
