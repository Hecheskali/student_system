-- Support headmaster-created teacher logins and assignment checks.
-- The Flutter app stores subjects/classes as JSON string arrays, while older
-- policies also expected {"name": "..."} objects. These helpers accept both.

create or replace function public.jsonb_text_array_values(payload jsonb)
returns table(item_value text)
language sql
immutable
as $$
  select nullif(
    btrim(
      case jsonb_typeof(item)
        when 'string' then item #>> '{}'
        when 'object' then coalesce(item ->> 'name', item ->> 'value')
        else null
      end
    ),
    ''
  )
  from jsonb_array_elements(coalesce(payload, '[]'::jsonb)) as source(item)
  where nullif(
    btrim(
      case jsonb_typeof(item)
        when 'string' then item #>> '{}'
        when 'object' then coalesce(item ->> 'name', item ->> 'value')
        else null
      end
    ),
    ''
  ) is not null
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
    from public.users u
    join lateral public.jsonb_text_array_values(u.assigned_classes) assigned(class_name)
      on true
    join public.classes c on c.name = assigned.class_name
    where u.id = auth.uid()
      and c.id = class_id
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
    from public.users u
    join lateral public.jsonb_text_array_values(u.subjects) assigned(subject_name)
      on true
    where u.id = auth.uid()
      and assigned.subject_name = subject_text
  )
$$;

drop policy if exists "teacher_see_assigned_classes" on public.classes;
create policy "teacher_see_assigned_classes" on public.classes
for select
to authenticated
using (
  is_teacher()
  and public.user_assigned_to_class(id)
);

drop policy if exists "teacher_see_students" on public.students;
create policy "teacher_see_students" on public.students
for select
to authenticated
using (
  is_teacher()
  and public.user_assigned_to_class(class_id)
);

drop policy if exists "teacher_see_results" on public.results;
create policy "teacher_see_results" on public.results
for select
to authenticated
using (
  is_teacher()
  and (
    public.user_assigned_to_class(class_id)
    or public.user_teaches_subject(subject)
  )
);

drop policy if exists "teacher_insert_results" on public.results;
create policy "teacher_insert_results" on public.results
for insert
to authenticated
with check (
  is_teacher()
  and public.user_assigned_to_class(class_id)
);

drop policy if exists "teacher_see_exams" on public.exams;
create policy "teacher_see_exams" on public.exams
for select
to authenticated
using (
  is_teacher()
  and public.user_assigned_to_class(class_id)
);

drop policy if exists "head_of_school_insert_school_users" on public.users;
create policy "head_of_school_insert_school_users" on public.users
for insert
to authenticated
with check (
  is_head_of_school()
  and school_name = public.get_user_school()
);

drop policy if exists "head_of_school_update_school_users" on public.users;
create policy "head_of_school_update_school_users" on public.users
for update
to authenticated
using (
  is_head_of_school()
  and school_name = public.get_user_school()
)
with check (
  is_head_of_school()
  and school_name = public.get_user_school()
);
