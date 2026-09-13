-- Safe bootstrap for the tables used by the Caderno web app.
-- It never drops application tables or data.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles add column if not exists display_name text;

create table if not exists public.academic_years (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  label text not null, starts_on date not null, ends_on date not null, is_active boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(owner_id,label)
);
create unique index if not exists one_active_academic_year_per_owner on public.academic_years(owner_id) where is_active;

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  name text not null, subject text not null, room text, color text not null default '#7cb092', period_objective text, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(owner_id,academic_year_id,name,subject)
);
create table if not exists public.students (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade, full_name text not null, internal_reference text, guardian_name text, guardian_email text, guardian_phone text, pedagogical_notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(owner_id,class_id,full_name)
);
create table if not exists public.student_goals (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade, period text not null, goal text not null, progress smallint not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.schedule_slots (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade, weekday smallint not null check(weekday between 1 and 5), starts_at time not null, ends_at time not null, room text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  academic_year_id uuid references public.academic_years(id) on delete cascade, class_id uuid references public.classes(id) on delete set null,
  event_type text not null, title text not null, details text, starts_at timestamptz not null, ends_at timestamptz, all_day boolean not null default false, reminder_minutes integer,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.lesson_plans (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade, schedule_slot_id uuid references public.schedule_slots(id) on delete set null,
  lesson_date date not null, objectives text, activities text, materials text, homework text, summary text, reflection text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(owner_id,class_id,lesson_date)
);
create table if not exists public.attendance_entries (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade, lesson_plan_id uuid not null references public.lesson_plans(id) on delete cascade,
  status text not null default 'present', late_minutes smallint, note text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(owner_id,student_id,lesson_plan_id)
);
create table if not exists public.assessments (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade, title text not null, assessment_date date, weight numeric(5,2) not null default 0, status text not null default 'planned', criteria jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.grade_entries (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id) on delete cascade, student_id uuid not null references public.students(id) on delete cascade, score numeric(5,2), rubric_scores jsonb not null default '{}'::jsonb, feedback text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(owner_id,assessment_id,student_id)
);
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  class_id uuid references public.classes(id) on delete set null, title text not null, due_at timestamptz, priority smallint not null default 2, is_done boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  class_id uuid references public.classes(id) on delete set null, student_id uuid references public.students(id) on delete set null, content text not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

-- Private, per-account access for every table.
do $$ declare t text; begin
  foreach t in array array['profiles','academic_years','classes','students','student_goals','schedule_slots','calendar_events','lesson_plans','attendance_entries','assessments','grade_entries','tasks','notes'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists app_owner_access on public.%I',t);
    if t='profiles' then execute format('create policy app_owner_access on public.%I for all using (id=auth.uid()) with check (id=auth.uid())',t);
    else execute format('create policy app_owner_access on public.%I for all using (owner_id=auth.uid()) with check (owner_id=auth.uid())',t); end if;
  end loop;
end $$;
notify pgrst, 'reload schema';

