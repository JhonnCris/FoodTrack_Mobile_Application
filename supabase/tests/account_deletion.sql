do $test$
declare
  test_user_id uuid := gen_random_uuid();
  test_food_id uuid;
  test_meal_id uuid;
begin
  begin
    insert into auth.users (id)
    values (test_user_id);

    insert into public.user_profiles (user_id)
    values (test_user_id);

    insert into public.foods (
      name,
      serving_label,
      calories_kcal,
      created_by_user_id,
      visibility
    )
    values (
      'Deletion trigger test food',
      '1 serving',
      100,
      test_user_id,
      'private'
    )
    returning id into test_food_id;

    insert into public.meal_entries (
      user_id,
      food_id,
      meal_type_code,
      servings,
      logged_at
    )
    values (
      test_user_id,
      test_food_id,
      'snack',
      1,
      now()
    )
    returning id into test_meal_id;

    insert into public.meal_entry_nutrition (
      meal_entry_id,
      calories_kcal,
      servings_at_capture,
      per_serving_calories_kcal
    )
    values (test_meal_id, 100, 1, 100);

    insert into public.user_disliked_foods (user_id, food_id)
    values (test_user_id, test_food_id);

    insert into public.user_favorites (user_id, food_id)
    values (test_user_id, test_food_id);

    insert into public.recommendation_events (
      user_id,
      trigger_type,
      recommendations
    )
    values (test_user_id, 'manual', '[]'::jsonb);

    delete from auth.users
    where id = test_user_id;

    if exists (
      select 1
      from auth.users
      where id = test_user_id
    ) or exists (
      select 1
      from public.meal_entries
      where user_id = test_user_id
    ) or exists (
      select 1
      from public.user_disliked_foods
      where user_id = test_user_id
    ) or exists (
      select 1
      from public.foods
      where created_by_user_id = test_user_id
    ) or exists (
      select 1
      from public.user_profiles
      where user_id = test_user_id
    ) or exists (
      select 1
      from public.recommendation_events
      where user_id = test_user_id
    ) or exists (
      select 1
      from public.user_favorites
      where user_id = test_user_id
    ) or exists (
      select 1
      from public.meal_entry_nutrition
      where meal_entry_id = test_meal_id
    ) then
      raise exception 'Auth deletion left application rows behind';
    end if;

    raise exception 'rollback account deletion test fixtures';
  exception
    when others then
      if sqlerrm <> 'rollback account deletion test fixtures' then
        raise;
      end if;
  end;
end;
$test$;
