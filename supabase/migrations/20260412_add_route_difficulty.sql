alter table public.route_templates
add column if not exists difficulty text not null default 'medium';

alter table public.route_templates
drop constraint if exists route_templates_difficulty_check;

alter table public.route_templates
add constraint route_templates_difficulty_check
check (difficulty in ('easy', 'medium', 'hard', 'expert'));
