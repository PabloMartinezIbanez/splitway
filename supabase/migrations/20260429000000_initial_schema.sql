-- Splitway initial schema (placeholder for iter 2).
-- Mirrors the SQLite tables in movile_app/lib/src/data/local/splitway_local_database.dart.
-- IMPORTANT: RLS is intentionally OFF here — this SQL is NOT yet safe to apply
-- to a public Supabase project. Iter 2 will add owner_id, RLS policies, and
-- proper auth wiring.

create extension if not exists "pgcrypto";

create table if not exists public.route_templates (
  id text primary key,
  name text not null,
  description text,
  path_json jsonb not null,
  start_finish_gate_json jsonb not null,
  difficulty text not null default 'medium' check (difficulty in ('easy','medium','hard')),
  created_at timestamptz not null default now()
);

create table if not exists public.sectors (
  id text primary key,
  route_id text not null references public.route_templates(id) on delete cascade,
  order_index integer not null,
  label text not null,
  gate_json jsonb not null
);

create index if not exists sectors_route_order_idx
  on public.sectors (route_id, order_index);

create table if not exists public.session_runs (
  id text primary key,
  route_id text not null references public.route_templates(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  status text not null check (status in ('draft','recording','completed','synced')),
  lap_summaries_json jsonb not null default '[]'::jsonb,
  sector_summaries_json jsonb not null default '[]'::jsonb,
  total_distance_m double precision not null default 0,
  max_speed_mps double precision not null default 0,
  avg_speed_mps double precision not null default 0
);

create index if not exists session_runs_route_started_idx
  on public.session_runs (route_id, started_at desc);

create table if not exists public.telemetry_points (
  session_id text not null references public.session_runs(id) on delete cascade,
  ts timestamptz not null,
  lat double precision not null,
  lng double precision not null,
  speed_mps double precision,
  accuracy_m double precision,
  bearing_deg double precision,
  altitude_m double precision
);

create index if not exists telemetry_points_session_ts_idx
  on public.telemetry_points (session_id, ts);

-- TODO iter 2: add owner_id uuid references auth.users, enable RLS, add policies.
