-- 
-- Supabase Row Level Security (RLS) Policies
-- Tight security based on exact school/district role matrix
--

-- Role Hierarchy:
-- District Level:
--   - district_admin: Can view/manage all schools, classes, students, results in district
--   - head_of_school: Can view/manage own school's data
--   - academic_master: Can view/manage grades for assigned subjects/classes
--   - teacher: Can view/upload grades for own class/subject

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
  select id from public.schools 
  where name = (select school_name from public.users where id = auth.uid())
  limit 1
$$;

create or replace function public.get_user_district_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.districts 
  where name = (select district_name from public.users where id = auth.uid())
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
    select 1 from public.classes c
    where c.id = class_id
    and c.name = any(
      select (jsonb_array_elements(assigned_classes)->>'name')
      from public.users
      where id = auth.uid()
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
    select 1 from public.users
    where id = auth.uid()
    and subject_text = any(
      select jsonb_array_elements(subjects) ->> 'name'
      from public.users
      where id = auth.uid()
    )
  )
$$;

-- =============================================================================
-- DISTRICTS RLS POLICIES
-- =============================================================================

alter table public.districts enable row level security;

-- District admins see all districts
create policy "district_admin_see_all_districts" on public.districts
for select
to authenticated
using (is_district_admin());

-- Head of school sees only own district
create policy "head_of_school_see_own_district" on public.districts
for select
to authenticated
using (
  is_head_of_school()
  and name = public.get_user_district()
);

-- Academic masters see only own district
create policy "academic_master_see_own_district" on public.districts
for select
to authenticated
using (
  is_academic_master()
  and name = public.get_user_district()
);

-- Teachers see only own district
create policy "teacher_see_own_district" on public.districts
for select
to authenticated
using (
  is_teacher()
  and name = public.get_user_district()
);

-- Only district admins can modify districts
create policy "district_admin_manage_districts" on public.districts
for all
to authenticated
using (is_district_admin())
with check (is_district_admin());

-- =============================================================================
-- SCHOOLS RLS POLICIES
-- =============================================================================

alter table public.schools enable row level security;

-- District admins see all schools in their district
create policy "district_admin_see_schools" on public.schools
for select
to authenticated
using (
  is_district_admin()
  and district_id = public.get_user_district_id()
);

-- Head of school sees only their own school
create policy "head_of_school_see_own_school" on public.schools
for select
to authenticated
using (
  is_head_of_school()
  and name = public.get_user_school()
);

-- Academic masters see only their school
create policy "academic_master_see_own_school" on public.schools
for select
to authenticated
using (
  is_academic_master()
  and name = public.get_user_school()
);

-- Teachers see only their school
create policy "teacher_see_own_school" on public.schools
for select
to authenticated
using (
  is_teacher()
  and name = public.get_user_school()
);

-- District admins can manage schools in their district
create policy "district_admin_manage_schools" on public.schools
for all
to authenticated
using (
  is_district_admin()
  and district_id = public.get_user_district_id()
)
with check (
  is_district_admin()
  and district_id = public.get_user_district_id()
);

-- Head of school can manage their own school
create policy "head_of_school_manage_own_school" on public.schools
for all
to authenticated
using (
  is_head_of_school()
  and name = public.get_user_school()
)
with check (
  is_head_of_school()
  and name = public.get_user_school()
);

-- =============================================================================
-- CLASSES RLS POLICIES
-- =============================================================================

alter table public.classes enable row level security;

-- District admins see all classes in their district
create policy "district_admin_see_classes" on public.classes
for select
to authenticated
using (
  is_district_admin()
  and district_id = public.get_user_district_id()
);

-- Head of school sees classes in their school
create policy "head_of_school_see_classes" on public.classes
for select
to authenticated
using (
  is_head_of_school()
  and school_id = public.get_user_school_id()
);

-- Academic masters see all classes in their school
create policy "academic_master_see_classes" on public.classes
for select
to authenticated
using (
  is_academic_master()
  and school_id = public.get_user_school_id()
);

-- Teachers see only classes they're assigned to
create policy "teacher_see_assigned_classes" on public.classes
for select
to authenticated
using (
  is_teacher()
  and public.user_assigned_to_class(id)
);

-- Head of school can manage classes in their school
create policy "head_of_school_manage_classes" on public.classes
for all
to authenticated
using (
  is_head_of_school()
  and school_id = public.get_user_school_id()
)
with check (
  is_head_of_school()
  and school_id = public.get_user_school_id()
);

-- =============================================================================
-- STUDENTS RLS POLICIES
-- =============================================================================

alter table public.students enable row level security;

-- District admins see all students in their district
create policy "district_admin_see_students" on public.students
for select
to authenticated
using (
  is_district_admin()
  and district_id = public.get_user_district_id()
);

-- Head of school sees students in their school
create policy "head_of_school_see_students" on public.students
for select
to authenticated
using (
  is_head_of_school()
  and school_id = public.get_user_school_id()
);

-- Academic masters see students in their school
create policy "academic_master_see_students" on public.students
for select
to authenticated
using (
  is_academic_master()
  and school_id = public.get_user_school_id()
);

-- Teachers see students in their assigned classes
create policy "teacher_see_students" on public.students
for select
to authenticated
using (
  is_teacher()
  and (
    class_id = any(
      select c.id from public.classes c
      where c.name = any(
        select (jsonb_array_elements(public.users.assigned_classes)->>'name')
        from public.users
        where id = auth.uid()
      )
    )
  )
);

-- Head of school can manage students in their school
create policy "head_of_school_manage_students" on public.students
for all
to authenticated
using (
  is_head_of_school()
  and school_id = public.get_user_school_id()
)
with check (
  is_head_of_school()
  and school_id = public.get_user_school_id()
);

-- =============================================================================
-- RESULTS RLS POLICIES
-- =============================================================================

alter table public.results enable row level security;

-- District admins see all results in their district
create policy "district_admin_see_results" on public.results
for select
to authenticated
using (
  is_district_admin()
  and class_id in (
    select c.id from public.classes c
    where c.district_id = public.get_user_district_id()
  )
);

-- Head of school sees results for their school
create policy "head_of_school_see_results" on public.results
for select
to authenticated
using (
  is_head_of_school()
  and class_id in (
    select c.id from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

-- Academic masters see results for their school
create policy "academic_master_see_results" on public.results
for select
to authenticated
using (
  is_academic_master()
  and class_id in (
    select c.id from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

-- Teachers can see and manage results for their classes and subjects
create policy "teacher_see_results" on public.results
for select
to authenticated
using (
  is_teacher()
  and (
    (
      -- Results from their assigned classes
      class_id = any(
        select c.id from public.classes c
        where c.name = any(
          select (jsonb_array_elements(public.users.assigned_classes)->>'name')
          from public.users
          where id = auth.uid()
        )
      )
    )
    or
    (
      -- Results in their assigned subject
      subject = any(
        select jsonb_array_elements(public.users.subjects)->>'name'
        from public.users
        where id = auth.uid()
      )
    )
  )
);

-- Only academic masters and head of school can insert/update results
create policy "academic_master_insert_results" on public.results
for insert
to authenticated
with check (
  (is_academic_master() or is_head_of_school())
  and class_id in (
    select c.id from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

create policy "academic_master_update_results" on public.results
for update
to authenticated
using (
  (is_academic_master() or is_head_of_school())
  and class_id in (
    select c.id from public.classes c
    where c.school_id = public.get_user_school_id()
  )
)
with check (
  (is_academic_master() or is_head_of_school())
  and class_id in (
    select c.id from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

-- Teachers can insert but not update/delete results
create policy "teacher_insert_results" on public.results
for insert
to authenticated
with check (
  is_teacher()
  and (
    class_id = any(
      select c.id from public.classes c
      where c.name = any(
        select (jsonb_array_elements(public.users.assigned_classes)->>'name')
        from public.users
        where id = auth.uid()
      )
    )
  )
);

-- =============================================================================
-- EXAMS RLS POLICIES
-- =============================================================================

alter table public.exams enable row level security;

-- District admins see all exams
create policy "district_admin_see_exams" on public.exams
for select
to authenticated
using (is_district_admin());

-- Head of school sees exams for their school
create policy "head_of_school_see_exams" on public.exams
for select
to authenticated
using (
  is_head_of_school()
  and class_id in (
    select c.id from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

-- Teachers see exams for their classes
create policy "teacher_see_exams" on public.exams
for select
to authenticated
using (
  is_teacher()
  and class_id = any(
    select c.id from public.classes c
    where c.name = any(
      select (jsonb_array_elements(public.users.assigned_classes)->>'name')
      from public.users
      where id = auth.uid()
    )
  )
);

-- Only head of school can create exams
create policy "head_of_school_create_exams" on public.exams
for insert
to authenticated
with check (
  is_head_of_school()
  and class_id in (
    select c.id from public.classes c
    where c.school_id = public.get_user_school_id()
  )
);

-- Teacher can only update own exams they created
create policy "teacher_manage_own_exams" on public.exams
for all
to authenticated
using (
  is_teacher()
  and teacher_id in (
    select id from public.teachers
    where user_id = auth.uid()
  )
)
with check (
  is_teacher()
  and teacher_id in (
    select id from public.teachers
    where user_id = auth.uid()
  )
);

-- =============================================================================
-- TEACHERS RLS POLICIES
-- =============================================================================

alter table public.teachers enable row level security;

-- Anyone can see teachers in their own school
create policy "see_teachers_in_school" on public.teachers
for select
to authenticated
using (school_name = public.get_user_school());

-- Head of school can manage teachers in their school
create policy "head_of_school_manage_teachers" on public.teachers
for all
to authenticated
using (
  is_head_of_school()
  and school_name = public.get_user_school()
)
with check (
  is_head_of_school()
  and school_name = public.get_user_school()
);

-- =============================================================================
-- USERS RLS POLICIES
-- =============================================================================

alter table public.users enable row level security;

-- Users can only see themselves
create policy "users_see_themselves" on public.users
for select
to authenticated
using (id = auth.uid());

-- Head of school can see other users in their school
create policy "head_of_school_see_school_users" on public.users
for select
to authenticated
using (
  is_head_of_school()
  and school_name = public.get_user_school()
);

-- Users can update only themselves
create policy "users_update_themselves" on public.users
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Admin can update any user
create policy "district_admin_update_users" on public.users
for all
to authenticated
using (is_district_admin())
with check (is_district_admin());

-- =============================================================================
-- SETTINGS RLS POLICIES
-- =============================================================================

alter table public.settings enable row level security;

-- All authenticated users can read settings
create policy "authenticated_read_settings" on public.settings
for select
to authenticated
using (true);

-- Only head of school or district admin can update settings
create policy "admin_manage_settings" on public.settings
for all
to authenticated
using (
  is_head_of_school() or is_district_admin()
)
with check (
  is_head_of_school() or is_district_admin()
);
