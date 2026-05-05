create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.users where id = auth.uid()
$$;

create or replace function public.current_school_name()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select school_name from public.users where id = auth.uid()
$$;

create or replace function public.current_district_name()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select district_name from public.users where id = auth.uid()
$$;

create or replace function public.is_admin_role()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_app_role() in ('head_of_school', 'academic_master'), false)
$$;

-- DISTRICTS
drop policy if exists "public read districts" on public.districts;
drop policy if exists "authenticated manage districts" on public.districts;
drop policy if exists "authenticated read districts" on public.districts;
drop policy if exists "admin manage districts" on public.districts;

create policy "authenticated read districts"
on public.districts
for select
to authenticated
using (true);

create policy "admin manage districts"
on public.districts
for all
to authenticated
using (public.is_admin_role())
with check (public.is_admin_role());

-- SCHOOLS
drop policy if exists "public read schools" on public.schools;
drop policy if exists "authenticated manage schools" on public.schools;
drop policy if exists "authenticated read schools" on public.schools;
drop policy if exists "admin manage schools" on public.schools;

create policy "authenticated read schools"
on public.schools
for select
to authenticated
using (true);

create policy "admin manage schools"
on public.schools
for all
to authenticated
using (public.is_admin_role())
with check (public.is_admin_role());

-- CLASSES
drop policy if exists "public read classes" on public.classes;
drop policy if exists "authenticated manage classes" on public.classes;
drop policy if exists "authenticated read classes" on public.classes;
drop policy if exists "admin manage classes" on public.classes;

create policy "authenticated read classes"
on public.classes
for select
to authenticated
using (true);

create policy "admin manage classes"
on public.classes
for all
to authenticated
using (public.is_admin_role())
with check (public.is_admin_role());

-- USERS
drop policy if exists "authenticated manage users" on public.users;
drop policy if exists "users read own profile" on public.users;
drop policy if exists "users update own profile" on public.users;
drop policy if exists "admin insert users" on public.users;

create policy "users read own profile"
on public.users
for select
to authenticated
using (id = auth.uid() or public.is_admin_role());

create policy "users update own profile"
on public.users
for update
to authenticated
using (id = auth.uid() or public.is_admin_role())
with check (id = auth.uid() or public.is_admin_role());

create policy "admin insert users"
on public.users
for insert
to authenticated
with check (public.is_admin_role());

-- TEACHERS
drop policy if exists "authenticated manage teachers" on public.teachers;
drop policy if exists "teachers read within assigned organization" on public.teachers;
drop policy if exists "teachers manage within assigned organization" on public.teachers;

create policy "teachers read within assigned organization"
on public.teachers
for select
to authenticated
using (
  public.is_admin_role()
  or school_name = public.current_school_name()
  or district_name = public.current_district_name()
);

create policy "teachers manage within assigned organization"
on public.teachers
for all
to authenticated
using (
  public.is_admin_role()
  or school_name = public.current_school_name()
)
with check (
  public.is_admin_role()
  or school_name = public.current_school_name()
);

-- STUDENTS
drop policy if exists "authenticated manage students" on public.students;
drop policy if exists "students read within scope" on public.students;
drop policy if exists "students manage within school" on public.students;

create policy "students read within scope"
on public.students
for select
to authenticated
using (
  public.is_admin_role()
  or exists (
    select 1
    from public.schools s
    where s.id = school_id
      and (
        s.name = public.current_school_name()
        or exists (
          select 1 from public.districts d
          where d.id = s.district_id
            and d.name = public.current_district_name()
        )
      )
  )
);

create policy "students manage within school"
on public.students
for all
to authenticated
using (
  public.is_admin_role()
  or exists (
    select 1 from public.schools s
    where s.id = school_id and s.name = public.current_school_name()
  )
)
with check (
  public.is_admin_role()
  or exists (
    select 1 from public.schools s
    where s.id = school_id and s.name = public.current_school_name()
  )
);

-- EXAMS
drop policy if exists "authenticated manage exams" on public.exams;
drop policy if exists "exams read within scope" on public.exams;
drop policy if exists "exams manage within scope" on public.exams;

create policy "exams read within scope"
on public.exams
for select
to authenticated
using (public.is_admin_role() or class_id is not null);

create policy "exams manage within scope"
on public.exams
for all
to authenticated
using (public.is_admin_role() or teacher_id is not null)
with check (public.is_admin_role() or teacher_id is not null);

-- RESULTS
drop policy if exists "authenticated manage results" on public.results;
drop policy if exists "results read within scope" on public.results;
drop policy if exists "results manage within school" on public.results;

create policy "results read within scope"
on public.results
for select
to authenticated
using (
  public.is_admin_role()
  or exists (
    select 1 from public.students s
    join public.schools sc on sc.id = s.school_id
    where s.id = student_id and sc.name = public.current_school_name()
  )
);

create policy "results manage within school"
on public.results
for all
to authenticated
using (
  public.is_admin_role()
  or exists (
    select 1 from public.students s
    join public.schools sc on sc.id = s.school_id
    where s.id = student_id and sc.name = public.current_school_name()
  )
)
with check (
  public.is_admin_role()
  or exists (
    select 1 from public.students s
    join public.schools sc on sc.id = s.school_id
    where s.id = student_id and sc.name = public.current_school_name()
  )
);

-- SETTINGS
drop policy if exists "authenticated manage settings" on public.settings;
drop policy if exists "authenticated read settings" on public.settings;
drop policy if exists "admin manage settings" on public.settings;

create policy "authenticated read settings"
on public.settings
for select
to authenticated
using (true);

create policy "admin manage settings"
on public.settings
for all
to authenticated
using (public.is_admin_role())
with check (public.is_admin_role());