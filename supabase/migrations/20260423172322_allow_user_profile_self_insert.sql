-- Keep Supabase API roles wired to the public schema. This is normally present
-- on new Supabase projects, but restoring a missing public schema requires
-- re-granting table privileges before RLS policies can take effect.

grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant all on all routines in schema public to anon, authenticated, service_role;

alter default privileges in schema public
grant all on tables to anon, authenticated, service_role;

alter default privileges in schema public
grant all on sequences to anon, authenticated, service_role;

alter default privileges in schema public
grant all on routines to anon, authenticated, service_role;

-- Allow a signed-in Supabase auth user to create the matching app profile row.
-- The Flutter login flow auto-provisions public.users when an auth account
-- exists without a profile, so RLS must allow id = auth.uid() inserts.

drop policy if exists "users_insert_themselves" on public.users;

create policy "users_insert_themselves"
on public.users
for insert
to authenticated
with check (id = auth.uid());
