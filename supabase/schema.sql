-- Caderno — esquema inicial para uma agenda individual de professor.
-- Idempotente: podes voltar a correr no SQL Editor sem falhar a meio.
-- Nunca coloques a service_role key no browser.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Limpeza (ordem inversa das FKs) para o script poder ser reexecutado
-- ---------------------------------------------------------------------------
drop trigger if exists on_auth_user_created on auth.users;

drop trigger if exists set_notes_updated_at on public.notes;
drop trigger if exists set_tasks_updated_at on public.tasks;
drop trigger if exists set_grade_entries_updated_at on public.grade_entries;
drop trigger if exists set_assessments_updated_at on public.assessments;
drop trigger if exists set_attendance_entries_updated_at on public.attendance_entries;
drop trigger if exists set_lesson_plans_updated_at on public.lesson_plans;
drop trigger if exists set_calendar_events_updated_at on public.calendar_events;
drop trigger if exists set_schedule_slots_updated_at on public.schedule_slots;
drop trigger if exists set_student_goals_updated_at on public.student_goals;
drop trigger if exists set_students_updated_at on public.students;
drop trigger if exists set_classes_updated_at on public.classes;
drop trigger if exists set_academic_years_updated_at on public.academic_years;
drop trigger if exists set_profiles_updated_at on public.profiles;

drop table if exists public.notes cascade;
drop table if exists public.tasks cascade;
drop table if exists public.grade_entries cascade;
drop table if exists public.assessments cascade;
drop table if exists public.attendance_entries cascade;
drop table if exists public.lesson_plans cascade;
drop table if exists public.calendar_events cascade;
drop table if exists public.schedule_slots cascade;
drop table if exists public.student_goals cascade;
drop table if exists public.students cascade;
drop table if exists public.classes cascade;
drop table if exists public.academic_years cascade;
drop table if exists public.profiles cascade;

drop type if exists public.assessment_status;
drop type if exists public.attendance_status;
drop type if exists public.event_type;

-- ---------------------------------------------------------------------------
-- Perfis + trigger de signup
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  timezone text not null default 'Europe/Lisbon',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Postgres 14+: EXECUTE FUNCTION (PROCEDURE continua a ser aceite, mas é o que
-- alguns editores rejeitam). DROP IF EXISTS em cima cobre o starter template.
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.event_type as enum ('lesson', 'assessment', 'meeting', 'visit', 'break', 'personal');
create type public.attendance_status as enum ('present', 'late', 'absent_justified', 'absent_unjustified');
create type public.assessment_status as enum ('planned', 'applied', 'marking', 'complete');

-- ---------------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------------
create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  label text not null,
  starts_on date not null,
  ends_on date not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint academic_year_valid_dates check (starts_on < ends_on),
  constraint academic_year_september_to_august check (
    extract(month from starts_on) = 9 and extract(month from ends_on) = 8
  ),
  unique (owner_id, label)
);

create unique index one_active_academic_year_per_owner
  on public.academic_years (owner_id) where is_active;

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  academic_year_id uuid not null references public.academic_years (id) on delete cascade,
  name text not null,
  subject text not null,
  room text,
  color text not null default '#7cb092',
  period_objective text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, academic_year_id, name, subject)
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  full_name text not null,
  internal_reference text,
  guardian_name text,
  guardian_email text,
  guardian_phone text,
  pedagogical_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, class_id, full_name)
);

create table public.student_goals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  period text not null,
  goal text not null,
  progress smallint not null default 0 check (progress between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.schedule_slots (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 5),
  starts_at time not null,
  ends_at time not null,
  room text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint schedule_slot_valid_time check (starts_at < ends_at)
);

create table public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  academic_year_id uuid references public.academic_years (id) on delete cascade,
  class_id uuid references public.classes (id) on delete set null,
  event_type public.event_type not null,
  title text not null check (char_length(title) <= 160),
  details text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  all_day boolean not null default false,
  reminder_minutes integer check (reminder_minutes >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_valid_end check (ends_at is null or starts_at <= ends_at)
);

create table public.lesson_plans (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  schedule_slot_id uuid references public.schedule_slots (id) on delete set null,
  lesson_date date not null,
  objectives text,
  activities text,
  materials text,
  homework text,
  summary text,
  reflection text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, class_id, lesson_date)
);

create table public.attendance_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  lesson_plan_id uuid not null references public.lesson_plans (id) on delete cascade,
  status public.attendance_status not null default 'present',
  late_minutes smallint check (late_minutes is null or late_minutes between 1 and 300),
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, student_id, lesson_plan_id)
);

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  title text not null check (char_length(title) <= 160),
  assessment_date date,
  weight numeric(5,2) not null default 0 check (weight between 0 and 100),
  status public.assessment_status not null default 'planned',
  criteria jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.grade_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  assessment_id uuid not null references public.assessments (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  score numeric(5,2) check (score between 0 and 20),
  rubric_scores jsonb not null default '{}'::jsonb,
  feedback text check (char_length(feedback) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, assessment_id, student_id)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  class_id uuid references public.classes (id) on delete set null,
  title text not null check (char_length(title) <= 200),
  due_at timestamptz,
  priority smallint not null default 2 check (priority between 1 and 3),
  is_done boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  class_id uuid references public.classes (id) on delete set null,
  student_id uuid references public.students (id) on delete set null,
  content text not null check (char_length(content) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Índices
-- ---------------------------------------------------------------------------
create index calendar_events_owner_starts_at_idx on public.calendar_events (owner_id, starts_at);
create index schedule_slots_owner_weekday_idx on public.schedule_slots (owner_id, weekday, starts_at);
create index students_class_idx on public.students (class_id, full_name);
create index tasks_owner_due_at_idx on public.tasks (owner_id, is_done, due_at);
create index attendance_student_idx on public.attendance_entries (student_id);

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------
create trigger set_profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger set_academic_years_updated_at before update on public.academic_years for each row execute function public.set_updated_at();
create trigger set_classes_updated_at before update on public.classes for each row execute function public.set_updated_at();
create trigger set_students_updated_at before update on public.students for each row execute function public.set_updated_at();
create trigger set_student_goals_updated_at before update on public.student_goals for each row execute function public.set_updated_at();
create trigger set_schedule_slots_updated_at before update on public.schedule_slots for each row execute function public.set_updated_at();
create trigger set_calendar_events_updated_at before update on public.calendar_events for each row execute function public.set_updated_at();
create trigger set_lesson_plans_updated_at before update on public.lesson_plans for each row execute function public.set_updated_at();
create trigger set_attendance_entries_updated_at before update on public.attendance_entries for each row execute function public.set_updated_at();
create trigger set_assessments_updated_at before update on public.assessments for each row execute function public.set_updated_at();
create trigger set_grade_entries_updated_at before update on public.grade_entries for each row execute function public.set_updated_at();
create trigger set_tasks_updated_at before update on public.tasks for each row execute function public.set_updated_at();
create trigger set_notes_updated_at before update on public.notes for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.academic_years enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.student_goals enable row level security;
alter table public.schedule_slots enable row level security;
alter table public.calendar_events enable row level security;
alter table public.lesson_plans enable row level security;
alter table public.attendance_entries enable row level security;
alter table public.assessments enable row level security;
alter table public.grade_entries enable row level security;
alter table public.tasks enable row level security;
alter table public.notes enable row level security;

create policy "profile owner manages own profile" on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

create policy "owner manages own academic years" on public.academic_years for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own classes" on public.classes for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own students" on public.students for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own student goals" on public.student_goals for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own schedule" on public.schedule_slots for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own calendar events" on public.calendar_events for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own lesson plans" on public.lesson_plans for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own attendance" on public.attendance_entries for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own assessments" on public.assessments for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own grades" on public.grade_entries for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own tasks" on public.tasks for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owner manages own notes" on public.notes for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Perfis para contas que já existiam antes deste trigger
insert into public.profiles (id, display_name)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', split_part(u.email, '@', 1))
from auth.users u
on conflict (id) do nothing;