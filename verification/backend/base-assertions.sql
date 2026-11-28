insert into auth.users (id, phone, phone_confirmed_at, raw_user_meta_data) values
  ('10000000-0000-0000-0000-000000000001', '905990000001', now(), '{"username_phone":"+905990000002"}'),
  ('10000000-0000-0000-0000-000000000002', '905990000002', now(), '{}'),
  ('10000000-0000-0000-0000-000000000003', '905990000003', now(), '{}'),
  ('10000000-0000-0000-0000-000000000004', '905990000004', now(), '{}'),
  ('10000000-0000-0000-0000-000000000005', '905990000005', now(), '{"full_name":"Test manager"}'),
  ('10000000-0000-0000-0000-000000000006', '905990000006', now(), '{"full_name":"Second advisor"}');
update public.profiles set staff_role='sales_advisor' where id='10000000-0000-0000-0000-000000000003';
update public.profiles set staff_role='accounting' where id='10000000-0000-0000-0000-000000000004';
update public.profiles set staff_role='management' where id='10000000-0000-0000-0000-000000000005';
update public.profiles set staff_role='sales_advisor' where id='10000000-0000-0000-0000-000000000006';

do $$
begin
  if has_table_privilege('authenticated','public.customers','truncate')
    or has_column_privilege('authenticated','public.customers','auth_user_id','update')
    or has_column_privilege('authenticated','public.profiles','staff_role','update')
    or has_column_privilege('authenticated','public.payment_submissions','status','insert')
    or has_table_privilege('authenticated','public.support_tickets','insert')
    or has_table_privilege('anon','public.customers','select')
    or has_function_privilege('anon','public.can_access_ticket(uuid)','execute')
    or has_function_privilege('authenticated','public.create_customer_with_contract(text,text,text,uuid,date,uuid,text,text,text)','execute') then
    raise exception 'Unexpected client privileges';
  end if;
end;
$$;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
select set_config('audit.customer_one',public.ensure_my_customer_record('Customer one')::text,false);
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
select set_config('audit.customer_two',public.ensure_my_customer_record('Customer two')::text,false);
reset role;

update public.customers set assigned_advisor_id='10000000-0000-0000-0000-000000000003'
  where id=current_setting('audit.customer_one')::uuid;
insert into public.promissory_notes (id,customer_id,note_number,installment_index,total_installments,amount,due_date)
  values ('20000000-0000-0000-0000-000000000001',current_setting('audit.customer_one')::uuid,'Test-001',1,1,50,current_date);

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
select set_config('audit.ticket',public.get_or_create_customer_ticket('finance')::text,false);
do $$
begin
  if not exists (select 1 from public.customers where phone='+905990000001' and contract_number is null)
    or (select count(*) from public.customers) <> 1
    or public.get_or_create_customer_ticket('finance')::text <> current_setting('audit.ticket') then
    raise exception 'Customer creation or ticket isolation failed';
  end if;
end;
$$;
insert into storage.objects (bucket_id,name) values
  ('payment-receipts',current_setting('audit.customer_one') || '/receipt.pdf'),
  ('message-attachments',current_setting('audit.ticket') || '/' || auth.uid()::text || '/message.pdf');
insert into public.ticket_messages (ticket_id,sender_id,body,attachment_object_path)
  values (current_setting('audit.ticket')::uuid,auth.uid(),'Test message',
    current_setting('audit.ticket') || '/' || auth.uid()::text || '/message.pdf');
insert into public.payment_submissions (note_id,customer_id,receipt_object_path,payment_method)
  values ('20000000-0000-0000-0000-000000000001',current_setting('audit.customer_one')::uuid,
    current_setting('audit.customer_one') || '/receipt.pdf','bank_transfer');
do $$
begin
  if not exists (select 1 from public.promissory_notes where status='verifying') then
    raise exception 'Receipt did not queue correctly';
  end if;
  delete from storage.objects where bucket_id='payment-receipts';
  if found then raise exception 'Submitted receipt could be deleted'; end if;
end;
$$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
do $$
begin
  if exists (select 1 from public.support_tickets) or exists (select 1 from public.ticket_messages)
    or exists (select 1 from public.payment_submissions) or exists (select 1 from storage.objects)
    or exists (select 1 from public.customers where id=current_setting('audit.customer_one')::uuid) then
    raise exception 'Customer rows leaked across accounts';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',false);
do $$
begin
  if (select count(*) from public.customers) <> 1 or exists (select 1 from public.payment_submissions)
    or exists (select 1 from public.ticket_messages) or (select count(*) from public.profiles) <> 1 then
    raise exception 'Sales advisor scope failed';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',false);
update public.payment_submissions set status='approved' where status='submitted';
do $$
begin
  if not exists (select 1 from public.payment_submissions where status='approved' and reviewed_by=auth.uid())
    or not exists (select 1 from public.promissory_notes where status='paid') then
    raise exception 'Accounting review failed';
  end if;
end;
$$;

insert into storage.objects(bucket_id, name) values ('customer-contracts', auth.uid()::text || '/contract.pdf');
select set_config('audit.contract_number',public.create_portal_contract(
  'Customer one', '', '+905990000001', '10000000-0000-0000-0000-000000000003', current_date,
  'New Project', 'A / 12', auth.uid()::text || '/contract.pdf', 'contract.pdf', 'application/pdf'
),false);
select set_config('audit.contract', id::text, false) from public.pending_contract_records
where contract_number=current_setting('audit.contract_number');
do $$
declare linked_id uuid;
begin
  if not exists (select 1 from public.pending_contract_records where id=current_setting('audit.contract')::uuid and project_name='New Project')
    or not exists (select 1 from storage.objects where bucket_id='customer-contracts')
    or exists (select 1 from public.customers where id=current_setting('audit.customer_one')::uuid and contract_number is not null) then
    raise exception 'Contract automatically linked to a phone login';
  end if;
  linked_id := public.link_pending_contract_account(current_setting('audit.contract')::uuid,
    current_setting('audit.customer_two')::uuid);
  raise exception 'An unrelated account was accepted';
exception when raise_exception then
  if sqlerrm <> 'The contract and account phone numbers do not match' then raise; end if;
end;
$$;
do $$
declare linked_id uuid;
begin
  linked_id := public.link_pending_contract_account(current_setting('audit.contract')::uuid,
    current_setting('audit.customer_one')::uuid);
  if linked_id::text <> current_setting('audit.customer_one')
    or not exists (select 1 from public.customers where id=linked_id and contract_status='approved'
      and project_name='New Project' and unit_label='A / 12')
    or not exists (select 1 from public.payment_submissions where customer_id=linked_id)
    or not exists (select 1 from public.support_tickets where customer_id=linked_id) then
    raise exception 'Manual contract link did not preserve account and records';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
do $$ begin
  if not exists (select 1 from storage.objects where bucket_id='customer-contracts')
    or not exists (select 1 from public.promissory_notes where customer_id=current_setting('audit.customer_one')::uuid) then
    raise exception 'Customer cannot read linked contract or existing notes';
  end if;
end $$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',false);
with folder as (insert into public.customer_folders(name, created_by) values ('Advisor folder', auth.uid()) returning id)
select set_config('audit.folder',id::text,false) from folder;
select public.assign_customer_to_portal_folder(current_setting('audit.customer_one')::uuid,current_setting('audit.folder')::uuid);

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000006',false);
do $$ begin
  if exists (select 1 from public.customer_folders) or exists (select 1 from public.customer_folder_memberships) then
    raise exception 'Folders are visible across advisors';
  end if;
end $$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',false);
do $$ begin
  if exists (select 1 from public.customer_folders) or exists (select 1 from public.customer_folder_memberships) then
    raise exception 'Accounting sees private advisor folders';
  end if;
  perform public.list_portal_accounts();
  raise exception 'Accounting opened the management directory';
exception when insufficient_privilege then null;
end $$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',false);
with folder as (insert into public.customer_folders(name, created_by) values ('Management folder', auth.uid()) returning id)
select set_config('audit.manager_folder',id::text,false) from folder;
select public.assign_customer_to_portal_folder(current_setting('audit.customer_one')::uuid,current_setting('audit.manager_folder')::uuid);
do $$ begin
  if (select count(*) from public.customer_folders) <> 2
    or (select count(*) from public.customer_folder_memberships) <> 2
    or (select count(*) from public.list_portal_accounts()) <> 5 then
    raise exception 'Management cannot see both private folders and account directory';
  end if;
end $$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',false);
select public.assign_customer_to_portal_folder(current_setting('audit.customer_one')::uuid,null);
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',false);
do $$ begin
  if not exists (select 1 from public.customer_folder_memberships where folder_id=current_setting('audit.manager_folder')::uuid)
    or (select count(*) from public.customer_folder_memberships) <> 1 then
    raise exception 'Removing the advisor folder affected another owner';
  end if;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',false);
do $$ begin
  perform public.perform_portal_account_action('10000000-0000-0000-0000-000000000003', 'create_folder', '{"name":"Unauthorized"}');
  raise exception 'Non-management account performed a delegated action';
exception when insufficient_privilege then null;
end $$;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',false);
select set_config('audit.delegated_folder',public.perform_portal_account_action(
  '10000000-0000-0000-0000-000000000003','create_folder','{"name":"Advisor delegated folder"}'
)::text,false);
select public.perform_portal_account_action('10000000-0000-0000-0000-000000000003','assign_folder',
  jsonb_build_object('customer_id',current_setting('audit.customer_one'),'folder_id',current_setting('audit.delegated_folder')));
do $$ begin
  perform public.perform_portal_account_action('10000000-0000-0000-0000-000000000003','assign_folder',
    jsonb_build_object('customer_id',current_setting('audit.customer_two'),'folder_id',current_setting('audit.delegated_folder')));
  raise exception 'Delegated assignment exceeded the advisor scope';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  if not exists (select 1 from public.list_delegated_portal_tickets('10000000-0000-0000-0000-000000000001')
      where id = current_setting('audit.ticket')::uuid)
    or exists (select 1 from public.list_delegated_portal_tickets('10000000-0000-0000-0000-000000000002')) then
    raise exception 'Delegated conversation listing scope mismatch';
  end if;
  perform public.perform_portal_account_action('10000000-0000-0000-0000-000000000002','send_message',
    jsonb_build_object('ticket_id',current_setting('audit.ticket'),'body','Unauthorized message'));
  raise exception 'Delegated conversation write exceeded the customer scope';
exception when insufficient_privilege then null;
end $$;
select set_config('audit.delegated_message',public.perform_portal_account_action(
  '10000000-0000-0000-0000-000000000001','send_message',
  jsonb_build_object('ticket_id',current_setting('audit.ticket'),'body','Authorized delegated message'))::text,false);
reset role;
do $$ begin
  if has_table_privilege('authenticated','public.portal_account_action_log','insert')
    or has_table_privilege('authenticated','public.portal_account_action_log','select')
    or not exists (select 1 from public.ticket_messages where id = current_setting('audit.delegated_message')::uuid
      and sender_id = '10000000-0000-0000-0000-000000000001')
    or not exists (select 1 from public.portal_account_action_log where resource_id = current_setting('audit.delegated_message')::uuid
      and actor_id = '10000000-0000-0000-0000-000000000005' and account_id = '10000000-0000-0000-0000-000000000001') then
    raise exception 'Missing or forgeable delegation audit attribution';
  end if;
end $$;

insert into public.promissory_notes (id,customer_id,note_number,installment_index,total_installments,amount,due_date)
values ('20000000-0000-0000-0000-000000000002',current_setting('audit.customer_one')::uuid,'Test-002',1,1,50,current_date);
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
insert into storage.objects (bucket_id,name) values ('payment-receipts',current_setting('audit.customer_one') || '/delegation-receipt.pdf');
with receipt as (
  insert into public.payment_submissions (note_id,customer_id,receipt_object_path,payment_method)
  values ('20000000-0000-0000-0000-000000000002',current_setting('audit.customer_one')::uuid,
    current_setting('audit.customer_one') || '/delegation-receipt.pdf','bank_transfer') returning id
)
select set_config('audit.delegated_receipt',id::text,false) from receipt;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',false);
do $$ begin
  perform public.perform_portal_account_action('10000000-0000-0000-0000-000000000003','review_payment',
    jsonb_build_object('submission_id',current_setting('audit.delegated_receipt'),'decision','approved'));
  raise exception 'An advisor can approve a receipt through delegation';
exception when insufficient_privilege then null;
end $$;
select public.perform_portal_account_action('10000000-0000-0000-0000-000000000004','review_payment',
  jsonb_build_object('submission_id',current_setting('audit.delegated_receipt'),'decision','approved'));
reset role;
do $$ begin
  if not exists (select 1 from public.payment_submissions where id=current_setting('audit.delegated_receipt')::uuid
      and status='approved' and reviewed_by='10000000-0000-0000-0000-000000000005')
    or not exists (select 1 from public.portal_account_action_log
      where resource_id=current_setting('audit.delegated_receipt')::uuid and action='review_payment'
      and actor_id='10000000-0000-0000-0000-000000000005' and account_id='10000000-0000-0000-0000-000000000004') then
    raise exception 'Delegated receipt did not preserve the actor and selected accounting account';
  end if;
end $$;

-- Reminder dates follow each note, including mid-month due dates.
insert into public.promissory_notes(id,customer_id,note_number,installment_index,total_installments,amount,due_date,status)
values
 ('30000000-0000-0000-0000-000000000001',current_setting('audit.customer_one')::uuid,'Reminder-before',1,1,50,'2030-05-16','pending'),
 ('30000000-0000-0000-0000-000000000002',current_setting('audit.customer_one')::uuid,'Reminder-today',1,1,50,'2030-05-14','pending'),
 ('30000000-0000-0000-0000-000000000003',current_setting('audit.customer_one')::uuid,'Reminder-late',1,1,50,'2030-05-12','overdue'),
 ('30000000-0000-0000-0000-000000000004',current_setting('audit.customer_one')::uuid,'Reminder-paid',1,1,50,'2030-05-14','paid'),
 ('30000000-0000-0000-0000-000000000005',current_setting('audit.customer_one')::uuid,'Reminder-review',1,1,50,'2030-05-14','verifying'),
 ('30000000-0000-0000-0000-000000000006',current_setting('audit.customer_one')::uuid,'Reminder-other-date',1,1,50,'2030-05-31','pending');
set role service_role;
do $$ begin
  if public.enqueue_due_payment_reminders('2030-05-14') <> 3
    or public.enqueue_due_payment_reminders('2030-05-14') <> 0 then
    raise exception 'Date-specific reminder selection or duplicate suppression failed';
  end if;
end $$;
reset role;
do $$ begin
  if has_function_privilege('authenticated','public.enqueue_due_payment_reminders(date)','execute')
    or has_function_privilege('authenticated','public.claim_push_delivery(bigint)','execute')
    or has_function_privilege('anon','public.push_worker_configuration(text)','execute')
    or has_table_privilege('authenticated','public.push_deliveries','select') then
    raise exception 'Push queue worker permissions leaked to clients';
  end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
select public.register_push_device('audit-device-token-for-account-change','android');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
select public.register_push_device('audit-device-token-for-account-change','android');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
do $$ begin
  if exists(select 1 from public.push_devices where token='audit-device-token-for-account-change') then
    raise exception 'Device registration remained attached to the previous account';
  end if;
end $$;
reset role;
select set_config('audit.push_job',(select id::text from public.push_outbox
  where data->>'note_id'='30000000-0000-0000-0000-000000000001' order by id desc limit 1),false);
set role service_role;
do $$ begin
  if (select count(*) from public.claim_push_delivery(current_setting('audit.push_job')::bigint))<>1
    or (select count(*) from public.claim_push_delivery(current_setting('audit.push_job')::bigint))<>0 then
    raise exception 'Concurrent workers can claim the same notification';
  end if;
end $$;
reset role;
