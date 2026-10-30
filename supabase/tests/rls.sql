begin;

insert into auth.users (id, aud, role, email, encrypted_password)
values
  ('00000000-0000-4000-8000-000000000101', 'authenticated', 'authenticated', 'rls-a@example.test', ''),
  ('00000000-0000-4000-8000-000000000102', 'authenticated', 'authenticated', 'rls-b@example.test', '');

insert into public.user_profiles (user_id, display_name)
values
  ('00000000-0000-4000-8000-000000000101', 'RLS user A'),
  ('00000000-0000-4000-8000-000000000102', 'RLS user B');

insert into public.foods (id, name, serving_label, calories_kcal, created_by_user_id, visibility)
values
  ('00000000-0000-4000-8000-000000000201', 'RLS private food A', '1 serving', 100, '00000000-0000-4000-8000-000000000101', 'private'),
  ('00000000-0000-4000-8000-000000000202', 'RLS private food B', '1 serving', 100, '00000000-0000-4000-8000-000000000102', 'private');

insert into public.user_favorites (user_id, food_id)
values
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201'),
  ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000202');

insert into public.user_disliked_foods (user_id, custom_name)
values
  ('00000000-0000-4000-8000-000000000101', 'RLS dislike A'),
  ('00000000-0000-4000-8000-000000000102', 'RLS dislike B');

insert into public.meal_entries (id, user_id, food_id, meal_type_code, servings, logged_at)
values
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201', 'snack', 1, now()),
  ('00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000202', 'snack', 1, now());

insert into public.meal_entry_nutrition (
  meal_entry_id,
  calories_kcal,
  servings_at_capture,
  per_serving_calories_kcal
)
values
  ('00000000-0000-4000-8000-000000000301', 100, 1, 100),
  ('00000000-0000-4000-8000-000000000302', 100, 1, 100);

insert into public.recommendation_events (user_id, trigger_type, recommendations)
values
  ('00000000-0000-4000-8000-000000000101', 'manual', '[]'::jsonb),
  ('00000000-0000-4000-8000-000000000102', 'manual', '[]'::jsonb);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000101', true);

do $$
begin
  if (select count(*) from public.user_profiles) <> 1
    or not exists (select 1 from public.user_profiles where user_id = auth.uid() and display_name = 'RLS user A') then
    raise exception 'Profile RLS isolation failed';
  end if;
  if (select count(*) from public.meal_entries) <> 1
    or not exists (select 1 from public.meal_entries where user_id = auth.uid()) then
    raise exception 'Meal RLS isolation failed';
  end if;
  if (select count(*) from public.meal_entry_nutrition) <> 1 then
    raise exception 'Nutrition-snapshot RLS isolation failed';
  end if;
  if (select count(*) from public.foods where created_by_user_id is not null) <> 1
    or not exists (select 1 from public.foods where created_by_user_id = auth.uid()) then
    raise exception 'Private custom-food RLS isolation failed';
  end if;
  if (select count(*) from public.user_favorites) <> 1
    or not exists (select 1 from public.user_favorites where user_id = auth.uid()) then
    raise exception 'Favorite RLS isolation failed';
  end if;
  if (select count(*) from public.user_disliked_foods) <> 1
    or not exists (select 1 from public.user_disliked_foods where user_id = auth.uid()) then
    raise exception 'Disliked-food RLS isolation failed';
  end if;
  if (select count(*) from public.recommendation_events) <> 1
    or not exists (select 1 from public.recommendation_events where user_id = auth.uid()) then
    raise exception 'Recommendation-history RLS isolation failed';
  end if;
end;
$$;

rollback;
