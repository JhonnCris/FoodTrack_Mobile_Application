-- Keep a profile and its dependent preference rows consistent in one transaction.
create or replace function public.save_user_profile(
  p_profile jsonb,
  p_known_allergen_codes text[],
  p_custom_allergen_names text[],
  p_disliked_food_names text[]
) returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.user_profiles (
    user_id, display_name, birth_date, height_cm, current_weight_kg, sex,
    goal_code, activity_level_code, diet_preference_code, timezone,
    calorie_target, protein_target_g, carbs_target_g, fat_target_g,
    targets_are_estimated, onboarding_completed_at
  ) values (
    auth.uid(), p_profile->>'display_name', (p_profile->>'birth_date')::date,
    (p_profile->>'height_cm')::numeric, (p_profile->>'current_weight_kg')::numeric,
    p_profile->>'sex', p_profile->>'goal_code', p_profile->>'activity_level_code',
    p_profile->>'diet_preference_code', p_profile->>'timezone',
    (p_profile->>'calorie_target')::numeric, (p_profile->>'protein_target_g')::numeric,
    (p_profile->>'carbs_target_g')::numeric, (p_profile->>'fat_target_g')::numeric,
    coalesce((p_profile->>'targets_are_estimated')::boolean, true),
    nullif(p_profile->>'onboarding_completed_at', '')::timestamptz
  ) on conflict (user_id) do update set
    display_name = excluded.display_name, birth_date = excluded.birth_date,
    height_cm = excluded.height_cm, current_weight_kg = excluded.current_weight_kg,
    sex = excluded.sex, goal_code = excluded.goal_code,
    activity_level_code = excluded.activity_level_code,
    diet_preference_code = excluded.diet_preference_code, timezone = excluded.timezone,
    calorie_target = excluded.calorie_target, protein_target_g = excluded.protein_target_g,
    carbs_target_g = excluded.carbs_target_g, fat_target_g = excluded.fat_target_g,
    targets_are_estimated = excluded.targets_are_estimated,
    onboarding_completed_at = coalesce(user_profiles.onboarding_completed_at, excluded.onboarding_completed_at);

  delete from public.user_allergies where user_id = auth.uid();
  insert into public.user_allergies(user_id, allergen_id)
    select auth.uid(), id from public.allergens
    where code = any(coalesce(p_known_allergen_codes, array[]::text[]));
  insert into public.user_allergies(user_id, custom_name)
    select auth.uid(), trim(name) from unnest(coalesce(p_custom_allergen_names, array[]::text[])) name
    where trim(name) <> '';
  delete from public.user_disliked_foods where user_id = auth.uid();
  insert into public.user_disliked_foods(user_id, custom_name)
    select auth.uid(), trim(name) from unnest(coalesce(p_disliked_food_names, array[]::text[])) name
    where trim(name) <> '';
end;
$$;
revoke all on function public.save_user_profile(jsonb, text[], text[], text[]) from public;
grant execute on function public.save_user_profile(jsonb, text[], text[], text[]) to authenticated;

alter table public.recommendation_events add column if not exists input_signature text;
update public.recommendation_events set input_signature = id::text where input_signature is null;
alter table public.recommendation_events alter column input_signature set not null;
alter table public.recommendation_events add constraint recommendation_events_user_signature_key unique (user_id, input_signature);

create or replace function public.record_recommendation_event(
  p_trigger_type text, p_input_signature text, p_daily_calories_kcal numeric, p_recommendations jsonb
) returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.recommendation_events(user_id, trigger_type, input_signature, daily_calories_kcal, recommendations)
  values (auth.uid(), p_trigger_type, p_input_signature, p_daily_calories_kcal, p_recommendations)
  on conflict (user_id, input_signature) do nothing;
end;
$$;
revoke all on function public.record_recommendation_event(text, text, numeric, jsonb) from public;
grant execute on function public.record_recommendation_event(text, text, numeric, jsonb) to authenticated;
