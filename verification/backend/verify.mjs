import { readdir, readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const db = new PGlite({ extensions: { pgcrypto } });
await db.exec(`
  create role anon;
  create role authenticated;
  create role service_role bypassrls;
  create schema auth;
  create schema storage;
  grant usage on schema auth, storage to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  create table auth.users (
    id uuid primary key, phone text unique, phone_confirmed_at timestamptz,
    raw_user_meta_data jsonb not null default '{}', raw_app_meta_data jsonb not null default '{"portal_registration":"customer_v1"}'
  );
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  create table storage.buckets (id text primary key, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (bucket_id text not null, name text not null,
    id uuid not null default gen_random_uuid(), metadata jsonb, created_at timestamptz not null default now(),
    primary key(bucket_id,name));
  alter table storage.objects enable row level security;
  grant select, insert, delete on storage.objects to authenticated;
  create function storage.foldername(name text) returns text[] language sql immutable as $$
    select (string_to_array(name,'/'))[1:cardinality(string_to_array(name,'/'))-1]
  $$;
  create publication supabase_realtime;
`);

const migrationDir = new URL('../../supabase/migrations/', import.meta.url);
for (const name of (await readdir(migrationDir)).filter(name => name.endsWith('.sql')).sort()) {
  try {
    await db.exec(await readFile(new URL(name, migrationDir), 'utf8'));
  } catch (error) {
    throw new Error(`${name}: ${error.message}`, { cause: error });
  }
}

const assertions = await readFile(new URL('./base-assertions.sql', import.meta.url), 'utf8');
try {
  await db.exec(assertions);
} catch (error) {
  console.error(`Authorization checks failed: ${error.code} ${error.message}`);
  await db.close();
  process.exit(1);
}
if (process.argv[2]) {
  await db.exec(await readFile(process.argv[2], 'utf8'));
}
try {
  await db.exec(await readFile(new URL('./finance-assertions.sql', import.meta.url), 'utf8'));
} catch (error) {
  console.error(`CRM finance SQL checks failed: ${error.code} ${error.message}\n${error.where ?? ''}`);
  await db.close();
  process.exit(1);
}
console.log('All migrations, authorization and CRM finance checks passed.');
await db.close();
