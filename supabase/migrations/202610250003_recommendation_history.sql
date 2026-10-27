create table public.recommendation_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trigger_type text not null check (trigger_type in ('onboarding', 'meal_change', 'profile_change', 'manual')),
  model_version text not null default 'rules-v1',
  daily_calories_kcal numeric(10,2) not null default 0,
  recommendations jsonb not null,
  created_at timestamptz not null default now()
);
create index recommendation_events_user_created_idx on public.recommendation_events(user_id, created_at desc);
alter table public.recommendation_events enable row level security;
create policy "own recommendation history" on public.recommendation_events for select to authenticated using (user_id = auth.uid());
create policy "create own recommendation history" on public.recommendation_events for insert to authenticated with check (user_id = auth.uid());
