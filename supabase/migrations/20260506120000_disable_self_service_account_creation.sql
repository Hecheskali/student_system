-- Account creation is now administrative only. Headmasters create teacher auth
-- accounts through the FastAPI service-role endpoint, which also creates the
-- linked public.users and public.teachers rows.

drop policy if exists "users_insert_themselves" on public.users;
