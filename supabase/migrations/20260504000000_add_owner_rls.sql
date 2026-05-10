-- Splitway iter 3: Add owner_id to all tables and enable Row-Level Security.
-- Each user only sees their own data.

-- 1. Add owner_id column to route_templates
alter table public.route_templates
  add column if not exists owner_id uuid references auth.users(id) on delete cascade;

-- Backfill existing rows (dev only — production should never have orphan rows).
-- update public.route_templates set owner_id = '<your-user-id>' where owner_id is null;

-- Make owner_id NOT NULL after backfill.
-- For new projects this is safe immediately:
alter table public.route_templates
  alter column owner_id set not null;

-- 2. Add owner_id to session_runs
alter table public.session_runs
  add column if not exists owner_id uuid references auth.users(id) on delete cascade;

alter table public.session_runs
  alter column owner_id set not null;

-- 3. Add owner_id to telemetry_points (denormalized for faster queries without JOIN)
alter table public.telemetry_points
  add column if not exists owner_id uuid references auth.users(id) on delete cascade;

alter table public.telemetry_points
  alter column owner_id set not null;

-- 4. Add updated_at for conflict resolution (last-write-wins)
alter table public.route_templates
  add column if not exists updated_at timestamptz not null default now();

alter table public.session_runs
  add column if not exists updated_at timestamptz not null default now();

-- 5. Enable RLS on all tables
alter table public.route_templates enable row level security;
alter table public.sectors enable row level security;
alter table public.session_runs enable row level security;
alter table public.telemetry_points enable row level security;

-- 6. RLS Policies — users can only CRUD their own rows.

-- route_templates
create policy "Users can view own routes"
  on public.route_templates for select
  using (auth.uid() = owner_id);

create policy "Users can insert own routes"
  on public.route_templates for insert
  with check (auth.uid() = owner_id);

create policy "Users can update own routes"
  on public.route_templates for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Users can delete own routes"
  on public.route_templates for delete
  using (auth.uid() = owner_id);

-- sectors (inherit ownership through route_id FK)
create policy "Users can view own sectors"
  on public.sectors for select
  using (
    exists (
      select 1 from public.route_templates rt
      where rt.id = sectors.route_id and rt.owner_id = auth.uid()
    )
  );

create policy "Users can insert own sectors"
  on public.sectors for insert
  with check (
    exists (
      select 1 from public.route_templates rt
      where rt.id = sectors.route_id and rt.owner_id = auth.uid()
    )
  );

create policy "Users can update own sectors"
  on public.sectors for update
  using (
    exists (
      select 1 from public.route_templates rt
      where rt.id = sectors.route_id and rt.owner_id = auth.uid()
    )
  );

create policy "Users can delete own sectors"
  on public.sectors for delete
  using (
    exists (
      select 1 from public.route_templates rt
      where rt.id = sectors.route_id and rt.owner_id = auth.uid()
    )
  );

-- session_runs
create policy "Users can view own sessions"
  on public.session_runs for select
  using (auth.uid() = owner_id);

create policy "Users can insert own sessions"
  on public.session_runs for insert
  with check (auth.uid() = owner_id);

create policy "Users can update own sessions"
  on public.session_runs for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Users can delete own sessions"
  on public.session_runs for delete
  using (auth.uid() = owner_id);

-- telemetry_points
create policy "Users can view own telemetry"
  on public.telemetry_points for select
  using (auth.uid() = owner_id);

create policy "Users can insert own telemetry"
  on public.telemetry_points for insert
  with check (auth.uid() = owner_id);

create policy "Users can delete own telemetry"
  on public.telemetry_points for delete
  using (auth.uid() = owner_id);

-- 7. Indexes for owner_id lookups
create index if not exists route_templates_owner_idx
  on public.route_templates (owner_id);

create index if not exists session_runs_owner_idx
  on public.session_runs (owner_id);
