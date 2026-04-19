create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.districts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  region_label text not null default '',
  total_schools integer not null default 0,
  total_students integer not null default 0,
  average_attendance double precision not null default 0,
  average_score double precision not null default 0,
  focus_area text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  district_id uuid references public.districts(id) on delete set null,
  name text not null,
  principal text not null default '',
  total_classes integer not null default 0,
  total_students integer not null default 0,
  average_attendance double precision not null default 0,
  average_score double precision not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete cascade,
  district_id uuid references public.districts(id) on delete set null,
  name text not null,
  teacher text not null default '',
  total_students integer not null default 0,
  average_attendance double precision not null default 0,
  average_score double precision not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text not null unique,
  role text not null default 'teacher',
  school_name text not null default '',
  district_name text not null default '',
  subject text,
  assigned_class text,
  subjects jsonb not null default '[]'::jsonb,
  assigned_classes jsonb not null default '[]'::jsonb,
  profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint users_role_check
    check (role in ('teacher', 'academic_master', 'head_of_school'))
);

create table if not exists public.teachers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  name text not null,
  email text not null,
  subject text not null default '',
  assigned_class text not null default '',
  can_upload_results boolean not null default true,
  can_edit_results boolean not null default true,
  can_register_students boolean not null default true,
  can_download_results boolean not null default true,
  subjects jsonb not null default '[]'::jsonb,
  assigned_classes jsonb not null default '[]'::jsonb,
  school_name text not null default '',
  district_name text not null default '',
  profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  district_id uuid references public.districts(id) on delete set null,
  school_id uuid references public.schools(id) on delete set null,
  class_id uuid references public.classes(id) on delete set null,
  full_name text not null,
  admission_number text unique,
  grade_level text not null default '',
  class_name text,
  average_score double precision not null default 0,
  gpa double precision not null default 0,
  attendance_rate double precision not null default 0,
  risk_level text not null default 'stable',
  subject_scores jsonb not null default '{}'::jsonb,
  monthly_performance jsonb not null default '[]'::jsonb,
  subjects jsonb not null default '[]'::jsonb,
  student_profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint students_risk_level_check
    check (risk_level in ('stable', 'watch', 'urgent'))
);

create table if not exists public.exams (
  id uuid primary key default gen_random_uuid(),
  class_id uuid references public.classes(id) on delete set null,
  teacher_id uuid references public.teachers(id) on delete set null,
  subject text not null default '',
  title text not null default '',
  exam_type text not null default '',
  term_label text,
  academic_year text,
  exam_date date,
  total_marks double precision,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.results (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.students(id) on delete cascade,
  exam_id uuid references public.exams(id) on delete set null,
  class_id uuid references public.classes(id) on delete set null,
  subject text not null default '',
  exam_type text not null default '',
  component text,
  label text not null default '',
  score double precision,
  average_score double precision,
  division text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.settings (
  id text primary key,
  upload_deadline timestamptz,
  edit_deadline timestamptz,
  editing_locked boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists schools_district_id_idx on public.schools(district_id);
create index if not exists classes_school_id_idx on public.classes(school_id);
create index if not exists classes_district_id_idx on public.classes(district_id);
create index if not exists students_class_id_idx on public.students(class_id);
create index if not exists students_school_id_idx on public.students(school_id);
create index if not exists students_district_id_idx on public.students(district_id);
create index if not exists teachers_user_id_idx on public.teachers(user_id);
create index if not exists results_student_id_idx on public.results(student_id);
create index if not exists results_exam_id_idx on public.results(exam_id);
create index if not exists exams_class_id_idx on public.exams(class_id);

drop trigger if exists set_districts_updated_at on public.districts;
create trigger set_districts_updated_at
before update on public.districts
for each row
execute function public.set_updated_at();

drop trigger if exists set_schools_updated_at on public.schools;
create trigger set_schools_updated_at
before update on public.schools
for each row
execute function public.set_updated_at();

drop trigger if exists set_classes_updated_at on public.classes;
create trigger set_classes_updated_at
before update on public.classes
for each row
execute function public.set_updated_at();

drop trigger if exists set_users_updated_at on public.users;
create trigger set_users_updated_at
before update on public.users
for each row
execute function public.set_updated_at();

drop trigger if exists set_teachers_updated_at on public.teachers;
create trigger set_teachers_updated_at
before update on public.teachers
for each row
execute function public.set_updated_at();

drop trigger if exists set_students_updated_at on public.students;
create trigger set_students_updated_at
before update on public.students
for each row
execute function public.set_updated_at();

drop trigger if exists set_exams_updated_at on public.exams;
create trigger set_exams_updated_at
before update on public.exams
for each row
execute function public.set_updated_at();

drop trigger if exists set_results_updated_at on public.results;
create trigger set_results_updated_at
before update on public.results
for each row
execute function public.set_updated_at();

drop trigger if exists set_settings_updated_at on public.settings;
create trigger set_settings_updated_at
before update on public.settings
for each row
execute function public.set_updated_at();

alter table public.districts enable row level security;
alter table public.schools enable row level security;
alter table public.classes enable row level security;
alter table public.users enable row level security;
alter table public.teachers enable row level security;
alter table public.students enable row level security;
alter table public.exams enable row level security;
alter table public.results enable row level security;
alter table public.settings enable row level security;

drop policy if exists "public read districts" on public.districts;
create policy "public read districts"
on public.districts
for select
using (true);

drop policy if exists "authenticated manage districts" on public.districts;
create policy "authenticated manage districts"
on public.districts
for all
to authenticated
using (true)
with check (true);

drop policy if exists "public read schools" on public.schools;
create policy "public read schools"
on public.schools
for select
using (true);

drop policy if exists "authenticated manage schools" on public.schools;
create policy "authenticated manage schools"
on public.schools
for all
to authenticated
using (true)
with check (true);

drop policy if exists "public read classes" on public.classes;
create policy "public read classes"
on public.classes
for select
using (true);

drop policy if exists "authenticated manage classes" on public.classes;
create policy "authenticated manage classes"
on public.classes
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated manage users" on public.users;
create policy "authenticated manage users"
on public.users
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated manage teachers" on public.teachers;
create policy "authenticated manage teachers"
on public.teachers
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated manage students" on public.students;
create policy "authenticated manage students"
on public.students
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated manage exams" on public.exams;
create policy "authenticated manage exams"
on public.exams
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated manage results" on public.results;
create policy "authenticated manage results"
on public.results
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated manage settings" on public.settings;
create policy "authenticated manage settings"
on public.settings
for all
to authenticated
using (true)
with check (true);
