alter table public.session_runs
add column if not exists manual_split_summaries jsonb not null default '[]'::jsonb;
