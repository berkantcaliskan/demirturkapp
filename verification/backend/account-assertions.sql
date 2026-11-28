-- GoTrue Admin API writes app_metadata after the first INSERT, in one transaction.
begin;
insert into auth.users(id,phone,raw_app_meta_data)
values('40000000-0000-0000-0000-000000000010','905990009990','{}');
update auth.users set raw_app_meta_data='{"portal_registration":"customer_v1"}'
where id='40000000-0000-0000-0000-000000000010';
commit;
-- Public signup may never bypass the server registration marker.
begin;
do $$ begin
  begin
    insert into auth.users(id,phone,raw_app_meta_data)
    values('40000000-0000-0000-0000-000000000011','905990009989','{}');
    set constraints all immediate;
    raise exception 'Public signup bypassed registration guard';
  exception when insufficient_privilege then null; end;
end $$;
rollback;

insert into auth.users(id,phone,email,phone_confirmed_at,raw_user_meta_data)
values('40000000-0000-0000-0000-000000000001','905990009991','account-test@example.invalid',now(),'{"full_name":"Account fixture"}');
set role authenticated;
select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-000000000001',false);
select set_config('audit.account_customer',public.ensure_my_customer_record('Account fixture')::text,false);
do $$ begin
  if not public.portal_account_active() then raise exception 'Live account blocked'; end if;
  if has_function_privilege('authenticated','public.portal_delete_account(uuid)','execute')
    or has_function_privilege('authenticated','public.portal_save_account(uuid,text,text)','execute') then
    raise exception 'Client can bypass password confirmation';
  end if;
end $$;
reset role;
update public.customers set contract_number='ACCOUNT-FIXTURE',contract_status='approved'
where id=current_setting('audit.account_customer')::uuid;
insert into public.support_tickets(id,customer_id,subject,category,channel)
values('40000000-0000-0000-0000-000000000002',current_setting('audit.account_customer')::uuid,'Retained business thread','general','general');
insert into public.ticket_messages(ticket_id,sender_id,body)
values('40000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001','Retained message fixture');
do $$ begin
  begin
    update auth.users set email='replacement@example.invalid' where id='40000000-0000-0000-0000-000000000001';
    raise exception 'Immutable email was changed';
  exception when insufficient_privilege then null; end;
end $$;
set role service_role;
select public.portal_delete_account('40000000-0000-0000-0000-000000000001');
reset role;
do $$ begin
  if exists(select 1 from auth.users where id='40000000-0000-0000-0000-000000000001') then raise exception 'Auth account retained'; end if;
  if not exists(select 1 from public.profiles where id='40000000-0000-0000-0000-000000000001' and full_name='Silinen hesap' and deleted_at is not null) then raise exception 'Attribution tombstone missing'; end if;
  if not exists(select 1 from public.ticket_messages where ticket_id='40000000-0000-0000-0000-000000000002') then raise exception 'Business message lost'; end if;
end $$;
set role authenticated;
select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-000000000001',false);
do $$ begin
  if public.portal_account_active() or exists(select 1 from public.profiles) or exists(select 1 from public.customers)
    or exists(select 1 from public.ticket_messages) or exists(select 1 from storage.objects) then
    raise exception 'Deleted account access token still reads data';
  end if;
end $$;
reset role;
insert into auth.users(id,phone,email,phone_confirmed_at,raw_user_meta_data)
values('40000000-0000-0000-0000-000000000003','905990009991','new-account-test@example.invalid',now(),'{"full_name":"New fixture"}');
set role authenticated;
select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-000000000003',false);
select public.ensure_my_customer_record('New fixture');
do $$ begin
  if exists(select 1 from public.customers where contract_number='ACCOUNT-FIXTURE') or exists(select 1 from public.ticket_messages) then
    raise exception 'Reused phone inherited deleted customer records';
  end if;
end $$;
reset role;
