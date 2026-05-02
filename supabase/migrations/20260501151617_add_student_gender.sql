alter table public.students
add column if not exists gender text not null default '';

with missing_admission_numbers as (
  select
    id,
    'S4217/-MIG-' || id::text as generated_admission_number
  from public.students
  where admission_number is null
    or btrim(admission_number) = ''
)
update public.students as students
set admission_number = missing.generated_admission_number
from missing_admission_numbers as missing
where students.id = missing.id;

update public.students
set class_name = ''
where class_name is null;

alter table public.students
alter column admission_number set not null,
alter column class_name set default '',
alter column class_name set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'students_gender_check'
      and conrelid = 'public.students'::regclass
  ) then
    alter table public.students
    add constraint students_gender_check
    check (gender in ('female', 'male'));
  end if;
end;
$$;

create index if not exists students_class_gender_name_idx
on public.students(class_name, gender, full_name);

notify pgrst, 'reload schema';
