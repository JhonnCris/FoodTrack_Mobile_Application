begin;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'recommendation_events'
      and column_name in ('input_signature', 'daily_calories_kcal')
  ) then
    raise exception 'Recommendation events still include minimized-away columns';
  end if;
  if has_table_privilege('authenticated', 'public.recommendation_events', 'INSERT') then
    raise exception 'Authenticated role can insert recommendation events directly';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.record_recommendation_event(text,jsonb)',
    'EXECUTE'
  ) then
    raise exception 'Authenticated role cannot call the recommendation event RPC';
  end if;
  if not exists (
    select 1
    from cron.job
    where jobname = 'prune-recommendation-events-90d'
      and command ilike '%created_at < now() - interval ''90 days''%'
  ) then
    raise exception 'The 90-day recommendation-history retention job is missing';
  end if;
end;
$$;

insert into auth.users (id, aud, role, email, encrypted_password)
values ('00000000-0000-4000-8000-000000000401', 'authenticated', 'authenticated', 'privacy@example.test', '');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000401', true);

select public.record_recommendation_event(
  'manual',
  '[{"food_id":"00000000-0000-4000-8000-000000000501"}]'::jsonb
);

do $$
begin
  if not exists (
    select 1
    from public.recommendation_events
    where user_id = auth.uid()
      and recommendations = '["00000000-0000-4000-8000-000000000501"]'::jsonb
  ) then
    raise exception 'Recommendation event was not stored in minimized food-id form';
  end if;

  begin
    perform public.record_recommendation_event(
      'manual',
      '[{"food_id":"test","reason":"sensitive rationale"}]'::jsonb
    );
    raise exception 'Recommendation RPC accepted an unminimized item';
  exception
    when others then
      if sqlerrm = 'Recommendation RPC accepted an unminimized item' then
        raise;
      end if;
  end;
end;
$$;

rollback;
