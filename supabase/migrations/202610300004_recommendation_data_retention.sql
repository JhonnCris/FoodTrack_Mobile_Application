create extension if not exists pg_cron with schema pg_catalog;

update public.recommendation_events
set recommendations = case
      when jsonb_typeof(recommendations) = 'array' then coalesce((
        select jsonb_agg(item.value -> 'food_id' order by item.ordinality)
        from jsonb_array_elements(recommendations)
          with ordinality as item(value, ordinality)
        where jsonb_typeof(item.value) = 'object'
          and jsonb_typeof(item.value -> 'food_id') is not distinct from 'string'
      ), '[]'::jsonb)
      else '[]'::jsonb
    end;

alter table public.recommendation_events
  drop constraint recommendation_events_user_signature_key,
  drop column daily_calories_kcal,
  drop column input_signature;

drop policy if exists "create own recommendation history"
  on public.recommendation_events;
revoke insert on table public.recommendation_events from authenticated;

drop function public.record_recommendation_event(text, text, numeric, jsonb);

create function public.record_recommendation_event(
  p_trigger_type text,
  p_recommendations jsonb
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_food_ids jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_recommendations is null
    or jsonb_typeof(p_recommendations) is distinct from 'array' then
    raise exception 'Recommendations must be an array of food ids';
  end if;
  if jsonb_array_length(p_recommendations) > 5 then
    raise exception 'At most five recommendation food ids are allowed';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_recommendations) as item(value)
    where jsonb_typeof(item.value) <> 'object'
      or jsonb_typeof(item.value -> 'food_id') is distinct from 'string'
  ) then
    raise exception 'Each recommendation must contain a food id';
  end if;

  select coalesce(
    jsonb_agg(item.value -> 'food_id' order by item.ordinality),
    '[]'::jsonb
  )
  into v_food_ids
  from jsonb_array_elements(p_recommendations)
    with ordinality as item(value, ordinality);

  insert into public.recommendation_events(
    user_id,
    trigger_type,
    recommendations
  )
  values (
    auth.uid(),
    p_trigger_type,
    v_food_ids
  );
end;
$$;

revoke all on function public.record_recommendation_event(text, jsonb)
  from public, anon;
grant execute on function public.record_recommendation_event(text, jsonb)
  to authenticated;

select cron.schedule(
  'prune-recommendation-events-90d',
  '15 3 * * *',
  $job$
    delete from public.recommendation_events
    where created_at < now() - interval '90 days';
  $job$
);
