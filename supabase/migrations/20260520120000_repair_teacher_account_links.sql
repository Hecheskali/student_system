-- Repair legacy teacher accounts that were created before the headmaster
-- account service consistently wrote public.users.role and profile.teacher_id.

update public.teachers as teachers
set user_id = users.id
from public.users as users
where teachers.user_id is null
  and users.role = 'teacher'
  and lower(teachers.email) = lower(users.email)
  and (
    teachers.school_name = ''
    or users.school_name = ''
    or teachers.school_name = users.school_name
  );

update public.users as users
set
  name = coalesce(nullif(btrim(teachers.name), ''), users.name),
  email = lower(teachers.email),
  role = 'teacher',
  school_name = coalesce(nullif(btrim(teachers.school_name), ''), users.school_name),
  district_name = coalesce(nullif(btrim(teachers.district_name), ''), users.district_name),
  subject = nullif(btrim(teachers.subject), ''),
  assigned_class = nullif(btrim(teachers.assigned_class), ''),
  subjects =
    case
      when nullif(btrim(teachers.subject), '') is null then '[]'::jsonb
      else jsonb_build_array(teachers.subject)
    end || coalesce(teachers.subjects, '[]'::jsonb),
  assigned_classes =
    case
      when nullif(btrim(teachers.assigned_class), '') is null then '[]'::jsonb
      else jsonb_build_array(teachers.assigned_class)
    end || coalesce(teachers.assigned_classes, '[]'::jsonb),
  profile = coalesce(users.profile, '{}'::jsonb) || jsonb_build_object(
    'teacher_id',
    teachers.id::text
  )
from public.teachers as teachers
where teachers.user_id = users.id
  and lower(teachers.email) = lower(users.email);

create or replace function public.is_teacher()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.get_user_role() = 'teacher'
    or exists (
      select 1
      from public.teachers teachers
      where teachers.user_id = auth.uid()
    ),
    false
  )
$$;

notify pgrst, 'reload schema';
