-- 
-- Supabase Row Level Security (RLS) Policies
-- Tight security based on exact school/district role matrix
--

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

create or replace function public.get_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.users where id = auth.uid()
$$;

create or replace function public.get_user_school()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select school_name from public.users where id = auth.uid()
$$;

create or replace function public.get_user_district()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select district_name from public.users where id = auth.uid()
$$;

create or replace function public.get_user_school_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.schools
  where name = (
    select school_name
    from public.users
    where id = auth.uid()
  )
  limit 1
$$;

create or replace function public.get_user_district_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.districts
  where name = (
    select district_name
    from public.users
    where id = auth.uid()
  )
  limit 1
$$;

create or replace function public.is_district_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.get_user_role() = 'district_admin', false)
$$;

create or replace function public.is_head_of_school()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.get_user_role() = 'head_of_school', false)
$$;

create or replace function public.is_academic_master()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.get_user_role() = 'academic_master', false)
$$;

create or replace function public.is_teacher()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.get_user_role() = 'teacher', false)
$$;

create or replace function public.user_assigned_to_class(class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.classes c
    where c.id = $1
      and c.name in (
        select item ->> 'name'
        from public.users u,
        jsonb_array_elements(u.assigned_classes) as item
        where u.id = auth.uid()
      )
  )
$$;

create or replace function public.user_teaches_subject(subject_text text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u,
    jsonb_array_elements(u.subjects) as item
    where u.id = auth.uid()
      and subject_text = item ->> 'name'
  )
$$;

-- =============================================================================
-- DROP OLD/DUPLICATE POLICIES
-- =============================================================================

drop policy if exists "district_admin_see_all_districts" on public.districts;
drop policy if exists "head_of_school_see_own_district" on public.districts;
drop policy if exists "academic_master_see_own_district" on public.districts;
drop policy if exists "teacher_see_own_district" on public.districts;
drop policy if exists "district_admin_manage_districts" on public.districts;

drop policy if exists "district_admin_see_schools" on public.schools;
drop policy if exists "head_of_school_see_own_school" on public.schools;
drop policy if exists "academic_master_see_own_school" on public.schools;
drop policy if exists "teacher_see_own_school" on public.schools;
drop policy if exists "district_admin_manage_schools" on public.schools;
drop policy if exists "head_of_school_manage_own_school" on public.schools;

drop policy if exists "district_admin_see_classes" on public.classes;
drop policy if exists "head_of_school_see_classes" on public.classes;
drop policy if exists "academic_master_see_classes" on public.classes;
drop policy if exists "teacher_see_assigned_classes" on public.classes;
drop policy if exists "head_of_school_manage_classes" on public.classes;

drop policy if exists "district_admin_see_students" on public.students;
drop policy if exists "head_of_school_see_students" on public.students;
drop policy if exists "academic_master_see_students" on public.students;
drop policy if exists "teacher_see_students" on public.students;
drop policy if exists "head_of_school_manage_students" on public.students;

drop policy if exists "district_admin_see_results" on public.results;
drop policy if exists "head_of_school_see_results" on public.results;
drop policy if exists "academic_master_see_results" on public.results;
drop policy if exists "teacher_see_results" on public.results;
drop policy if exists "academic_master_insert_results" on public.results;
drop policy if exists "academic_master_update_results" on public.results;
drop policy if exists "teacher_insert_results" on public.results;

drop policy if exists "district_admin_see_exams" on public.exams;
drop policy if exists "head_of_school_see_exams" on public.exams;
drop policy if exists "teacher_see_exams" on public.exams;
drop policy if exists "head_of_school_create_exams" on public.exams;
drop policy if exists "teacher_manage_own_exams" on public.exams;

drop policy if exists "see_teachers_in_school" on public.teachers;
drop policy if exists "head_of_school_manage_teachers" on public.teachers;

drop policy if exists "users_see_themselves" on public.users;
drop policy if exists "head_of_school_see_school_users" on public.users;
drop policy if exists "users_update_themselves" on public.users;
drop policy if exists "district_admin_update_users" on public.users;

drop policy if exists "authenticated_read_settings" on public.settings;
drop policy if exists "admin_manage_settings" on public.settings;

-- Policies from previous migration, drop to avoid conflicts/duplicates

drop policy if exists "authenticated read districts" on public.districts;
drop policy if exists "admin manage districts" on public.districts;

drop policy if exists "authenticated read schools" on public.schools;
drop policy if exists "admin manage schools" on public.schools;

drop policy if exists "authenticated read classes" on public.classes;
drop policy if exists "admin manage classes" on public.classes;

drop policy if exists "users read own profile" on public.users;
drop policy if exists "users update own profile" on public.users;
drop policy if exists "admin insert users" on public.users;

drop policy if exists "teachers read within assigned organization" on public.teachers;
drop policy if exists "teachers manage within assigned organization" on public.teachers;

drop policy if exists "students read within scope" on public.students;
drop policy if exists "students manage within school" on public.students;

drop policy if exists "exams read within scope" on public.exams;
drop policy if exists "exams manage within scope" on public.exams;

drop policy if exists "results read within scope" on public.results;
drop policy if exists "results manage within school" on public.results;

drop policy if exists "authenticated read settings" on public.settings;
drop policy if exists "admin manage settings" on public.settings;

-- =============================================================================
-- DISTRICTS RLS POLICIES
-- =============================================================================

alter table public.districts enable row level security;

create policy "district_admin_see_all_districts"
on public.districts
for select
to authenticated
using (public.is_district_admin());

create policy "head_of_school_see_own_district"
on public.districts
for select
to authenticated
using (
  public.is_head_of_school()
  and name = public.get_user_district()
);

create policy "academic_master_see_own_district"
on public.districts
for select
to authenticated
using (
  public.is_academic_master()
  and name = public.get_user_district()
);

create policy "teacher_see_own_district"
on public.districts
for select
to authenticated
using (
  public.is_teacher()
  and name = public.get_user_district()
);

create policy "authenticated_read_all_districts"
on public.districts
for select
to authenticated
using (true);

create policy "district_admin_manage_districts"
on public.districts
for all
to authenticated
using (public.is_district_admin())
with check (public.is_district_admin());

-- =============================================================================
-- SCHOOLS RLS POLICIES
-- =============================================================================

alter table public.schools enable row level security;

create policy "district_admin_see_schools"
on public.schools
for select
to authenticated
using (
  public.is_district_admin()
  and district_id = public.get_user_district_id()
);

create policy "head_of_school_see_own_school"
on public.schools
for select
to authenticated
using (
  public.is_head_of_school()
  and name = public.get_user_school()
);

create policy "academic_master_see_own_school"
on public.schools
for select
to authenticated
using (
  public.is_academic_master()
  and name = public.get_user_school()
);

create policy "teacher_see_own_school"
on public.schools
for select
to authenticated
using (
  public.is_teacher()
  and name = public.get_user_school()
);

create policy "authenticated_read_all_schools"
on public.schools
for select
to authenticated
using (true);

create policy "district_admin_manage_schools"
on public.schools
for all
to authenticated
using (
  public.is_district_admin()
  and district_id = public.get_user_district_id()
)
with check (
  public.is_district_admin()
  and district_id = public.get_user_district_id()
);

create policy "head_of_school_manage_own_school"
on public.schools
for all
to authenticated
using (
  public.is_head_of_school()
  and name = public.get_user_school()
)
with check (
  public.is_head_of_school()
  and name = public.get_user_school()
);

-- =============================================================================
-- CLASSES RLS POLICIES
-- =============================================================================

alter table public.classes enable row level security;

create policy "district_admin_see_classes"
on public.classes
for select
to authenticated
using (
  public.is_district_admin()
  and district_id = public.get_user_district_id()
);

create policy "head_of_school_see_classes"
on public.classes
for select
to authenticated
using (
  public.is_head_of_school()
  and school_id = public.get_user_school_id()
);

create policy "academic_master_see_classes"
on public.classes
for select
to authenticated
using (
  public.is_academic_master()
  and school_id = public.get_user_school_id()
);

create policy "teacher_see_assigned_classes"
on public.classes
for select
to authenticated
using (
  public.is_teacher()
  and public.user_assigned_to_class(id)
);

create policy "authenticated_read_all_classes"
on public.classes
for select
to authenticated
using (true);

create policy "head_of_school_manage_classes"
on public.classes
for all
to authenticated
using (
  public.is_head_of_school()
  and school_id = public.get_user_school_id()
)
with check (
  public.is_head_of_school()
  and school_id = public.get_user_school_id()
);

-- =============================================================================
-- STUDENTS RLS POLICIES
-- =============================================================================

alter table public.students enable row level security;

create policy "district_admin_see_students"
on public.students
for select
to authenticated
using (
  public.is_district_admin()
  and district_id = public.get_user_district_id()
);

create policy "head_of_school_see_students"
on public.students
for select
to authenticated
using (
  public.is_head_of_school()
  and school_id = public.get_user_school_id()
);

create policy "academic_master_see_students"
on public.students
for select
to authenticated
using (
  public.is_academic_master()
  and school_id = public.get_user_school_id()
);

create policy "teacher_see_students"
on public.students
for select
to authenticated
using (
  public.is_teacher()
  and public.user_assigned_to_class(class_id)
);

create policy "head_of_school_manage_students"
on public.students
for all
to authenticated
using (
  public.is_head_of_school()
  and school_id = public.get_user_school_id()
)
with check (
  public.is_head_of_school()
  and school_id = public.get_user_school_id()
);

-- =============================================================================
-- RESULTS RLS POLICIES
-- =============================================================================

alter table public.results enable row level security;

create policy "district_admin_see_results"
on public.results
for select
to authenticated
using (
  public.is_district_admin()
  and class_id in (
    select c.id
    from public.classes c
    where c.district_id = public.get_user_district_id()
  )
);

create policy "head_of_school_see_results"
on public.results
for select
to authenticated
using (
  public.is_head_of_school()
  and class_id in (
    select c.id
    from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

create policy "academic_master_see_results"
on public.results
for select
to authenticated
using (
  public.is_academic_master()
  and class_id in (
    select c.id
    from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

create policy "teacher_see_results"
on public.results
for select
to authenticated
using (
  public.is_teacher()
  and (
    public.user_assigned_to_class(class_id)
    or public.user_teaches_subject(subject)
  )
);

create policy "academic_master_insert_results"
on public.results
for insert
to authenticated
with check (
  (public.is_academic_master() or public.is_head_of_school())
  and class_id in (
    select c.id
    from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

create policy "academic_master_update_results"
on public.results
for update
to authenticated
using (
  (public.is_academic_master() or public.is_head_of_school())
  and class_id in (
    select c.id
    from public.classes c
    where c.school_id = public.get_user_school_id()
  )
)
with check (
  (public.is_academic_master() or public.is_head_of_school())
  and class_id in (
    select c.id
    from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

create policy "teacher_insert_results"
on public.results
for insert
to authenticated
with check (
  public.is_teacher()
  and public.user_assigned_to_class(class_id)
);

-- =============================================================================
-- EXAMS RLS POLICIES
-- =============================================================================

alter table public.exams enable row level security;

create policy "district_admin_see_exams"
on public.exams
for select
to authenticated
using (public.is_district_admin());

create policy "head_of_school_see_exams"
on public.exams
for select
to authenticated
using (
  public.is_head_of_school()
  and class_id in (
    select c.id
    from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

create policy "teacher_see_exams"
on public.exams
for select
to authenticated
using (
  public.is_teacher()
  and public.user_assigned_to_class(class_id)
);

create policy "head_of_school_create_exams"
on public.exams
for insert
to authenticated
with check (
  public.is_head_of_school()
  and class_id in (
    select c.id
    from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

create policy "teacher_manage_own_exams"
on public.exams
for all
to authenticated
using (
  public.is_teacher()
  and teacher_id in (
    select id
    from public.teachers
    where user_id = auth.uid()
  )
)
with check (
  public.is_teacher()
  and teacher_id in (
    select id
    from public.teachers
    where user_id = auth.uid()
  )
);

-- =============================================================================
-- TEACHERS RLS POLICIES
-- =============================================================================

alter table public.teachers enable row level security;

create policy "see_teachers_in_school"
on public.teachers
for select
to authenticated
using (school_name = public.get_user_school());

create policy "head_of_school_manage_teachers"
on public.teachers
for all
to authenticated
using (
  public.is_head_of_school()
  and school_name = public.get_user_school()
)
with check (
  public.is_head_of_school()
  and school_name = public.get_user_school()
);

-- =============================================================================
-- USERS RLS POLICIES
-- =============================================================================

alter table public.users enable row level security;

create policy "users_see_themselves"
on public.users
for select
to authenticated
using (id = auth.uid());

create policy "head_of_school_see_school_users"
on public.users
for select
to authenticated
using (
  public.is_head_of_school()
  and school_name = public.get_user_school()
);

create policy "users_update_themselves"
on public.users
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "district_admin_update_users"
on public.users
for all
to authenticated
using (public.is_district_admin())
with check (public.is_district_admin());

-- =============================================================================
-- SETTINGS RLS POLICIES
-- =============================================================================

alter table public.settings enable row level security;

create policy "authenticated_read_settings"
on public.settings
for select
to authenticated
using (true);

create policy "admin_manage_settings"
on public.settings
for all
to authenticated
using (
  public.is_head_of_school() or public.is_district_admin()
)
with check (
  public.is_head_of_school() or public.is_district_admin()
);