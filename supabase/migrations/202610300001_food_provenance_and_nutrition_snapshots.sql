-- Keep nutrition and allergen provenance explicit. Existing catalog values
-- remain unverified until their underlying sources have been reviewed.
alter table public.foods
  add column nutrition_source_name text,
  add column nutrition_source_url text,
  add column allergen_source_name text,
  add column allergen_source_url text,
  add column reviewed_at timestamptz;

update public.foods
set source_name = null
where source_name = 'FoodTrack starter catalog';

update public.foods
set is_verified = false
where is_verified;

alter table public.foods
  add constraint verified_foods_require_provenance check (
    not is_verified or (
      created_by_user_id is null
      and nullif(btrim(nutrition_source_name), '') is not null
      and nutrition_source_url is not null
      and nutrition_source_url ~* '^https://'
      and nullif(btrim(allergen_source_name), '') is not null
      and allergen_source_url is not null
      and allergen_source_url ~* '^https://'
      and reviewed_at is not null
    )
  );

-- Store the per-food-serving nutrients captured when a meal is logged.
-- Historical rows can only be backfilled from their existing totals and
-- serving count; source edits made before this migration cannot be recovered.
alter table public.meal_entry_nutrition
  add column servings_at_capture numeric(8,3),
  add column per_serving_calories_kcal numeric(10,4),
  add column per_serving_protein_g numeric(10,4),
  add column per_serving_carbs_g numeric(10,4),
  add column per_serving_fat_g numeric(10,4),
  add column per_serving_fiber_g numeric(10,4),
  add column per_serving_sugar_g numeric(10,4),
  add column per_serving_sodium_mg numeric(10,4);

update public.meal_entry_nutrition n
set servings_at_capture = e.servings,
    per_serving_calories_kcal = n.calories_kcal / e.servings,
    per_serving_protein_g = n.protein_g / e.servings,
    per_serving_carbs_g = n.carbs_g / e.servings,
    per_serving_fat_g = n.fat_g / e.servings,
    per_serving_fiber_g = n.fiber_g / e.servings,
    per_serving_sugar_g = n.sugar_g / e.servings,
    per_serving_sodium_mg = n.sodium_mg / e.servings
from public.meal_entries e
where e.id = n.meal_entry_id;

alter table public.meal_entry_nutrition
  alter column servings_at_capture set not null,
  alter column per_serving_calories_kcal set not null,
  add constraint meal_entry_nutrition_capture_servings_positive
    check (servings_at_capture > 0),
  add constraint meal_entry_nutrition_per_serving_calories_nonnegative
    check (per_serving_calories_kcal >= 0),
  add constraint meal_entry_nutrition_per_serving_macros_nonnegative
    check (
      (per_serving_protein_g is null or per_serving_protein_g >= 0)
      and (per_serving_carbs_g is null or per_serving_carbs_g >= 0)
      and (per_serving_fat_g is null or per_serving_fat_g >= 0)
      and (per_serving_fiber_g is null or per_serving_fiber_g >= 0)
      and (per_serving_sugar_g is null or per_serving_sugar_g >= 0)
      and (per_serving_sodium_mg is null or per_serving_sodium_mg >= 0)
    );

create or replace function public.create_meal_entry(
  p_food_id uuid,
  p_meal_type_code text,
  p_servings numeric,
  p_logged_at timestamptz,
  p_notes text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_food public.foods;
  v_entry_id uuid;
  v_servings numeric(8,3);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_servings is null or p_servings <= 0 then
    raise exception 'Servings must be greater than zero';
  end if;
  v_servings := p_servings;
  if v_servings <= 0 then
    raise exception 'Servings must be greater than zero';
  end if;
  select * into v_food
  from public.foods
  where id = p_food_id
    and (visibility = 'public' or created_by_user_id = auth.uid());
  if not found then raise exception 'Food not found or unavailable'; end if;

  insert into public.meal_entries(
    user_id, food_id, meal_type_code, servings, logged_at, notes
  ) values (
    auth.uid(), p_food_id, p_meal_type_code, v_servings, p_logged_at, p_notes
  ) returning id into v_entry_id;

  insert into public.meal_entry_nutrition(
    meal_entry_id, calories_kcal, protein_g, carbs_g, fat_g, fiber_g,
    sugar_g, sodium_mg, servings_at_capture, per_serving_calories_kcal,
    per_serving_protein_g, per_serving_carbs_g, per_serving_fat_g,
    per_serving_fiber_g, per_serving_sugar_g, per_serving_sodium_mg
  ) values (
    v_entry_id, v_food.calories_kcal * v_servings,
    v_food.protein_g * v_servings, v_food.carbs_g * v_servings,
    v_food.fat_g * v_servings, v_food.fiber_g * v_servings,
    v_food.sugar_g * v_servings, v_food.sodium_mg * v_servings,
    v_servings, v_food.calories_kcal, v_food.protein_g, v_food.carbs_g,
    v_food.fat_g, v_food.fiber_g, v_food.sugar_g, v_food.sodium_mg
  );
  return v_entry_id;
end;
$$;

revoke all on function public.create_meal_entry(uuid, text, numeric, timestamptz, text) from public;
grant execute on function public.create_meal_entry(uuid, text, numeric, timestamptz, text) to authenticated;

create or replace function public.update_meal_entry_servings(
  p_entry_id uuid,
  p_servings numeric
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_snapshot public.meal_entry_nutrition;
  v_servings numeric(8,3);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_servings is null or p_servings <= 0 then
    raise exception 'Servings must be greater than zero';
  end if;
  v_servings := p_servings;
  if v_servings <= 0 then
    raise exception 'Servings must be greater than zero';
  end if;

  select n.* into v_snapshot
  from public.meal_entries e
  join public.meal_entry_nutrition n on n.meal_entry_id = e.id
  where e.id = p_entry_id and e.user_id = auth.uid()
  for update of e, n;
  if not found then raise exception 'Meal entry or nutrition snapshot not found'; end if;

  update public.meal_entries
  set servings = v_servings
  where id = p_entry_id and user_id = auth.uid();

  update public.meal_entry_nutrition
  set calories_kcal = v_snapshot.per_serving_calories_kcal * v_servings,
      protein_g = v_snapshot.per_serving_protein_g * v_servings,
      carbs_g = v_snapshot.per_serving_carbs_g * v_servings,
      fat_g = v_snapshot.per_serving_fat_g * v_servings,
      fiber_g = v_snapshot.per_serving_fiber_g * v_servings,
      sugar_g = v_snapshot.per_serving_sugar_g * v_servings,
      sodium_mg = v_snapshot.per_serving_sodium_mg * v_servings,
      servings_at_capture = v_servings,
      captured_at = now()
  where meal_entry_id = p_entry_id;
end;
$$;

revoke all on function public.update_meal_entry_servings(uuid, numeric) from public;
grant execute on function public.update_meal_entry_servings(uuid, numeric) to authenticated;
