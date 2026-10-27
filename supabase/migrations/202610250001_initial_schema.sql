-- FoodTrack backend foundation. Nutrition values are per defined serving.
-- Food-image storage is intentionally not included yet.
create extension if not exists pgcrypto;

create table public.goals (code text primary key, display_name text not null);
create table public.activity_levels (code text primary key, display_name text not null, tdee_factor numeric(5,3) not null check (tdee_factor > 0));
create table public.diet_preferences (code text primary key, display_name text not null);
create table public.food_categories (id uuid primary key default gen_random_uuid(), code text unique not null, display_name text not null);
create table public.diet_tags (code text primary key, display_name text not null);
create table public.allergens (id uuid primary key default gen_random_uuid(), code text unique not null, display_name text not null);
create table public.meal_types (code text primary key, display_name text not null);

create table public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text, birth_date date, height_cm numeric(5,1) check (height_cm between 80 and 250),
  current_weight_kg numeric(6,2) check (current_weight_kg between 20 and 400),
  sex text check (sex in ('male', 'female', 'prefer_not_to_say')),
  goal_code text references public.goals(code), activity_level_code text references public.activity_levels(code),
  diet_preference_code text not null default 'none' references public.diet_preferences(code),
  timezone text not null default 'Asia/Manila', calorie_target numeric(8,2) check (calorie_target >= 0),
  protein_target_g numeric(8,2) check (protein_target_g >= 0), carbs_target_g numeric(8,2) check (carbs_target_g >= 0),
  fat_target_g numeric(8,2) check (fat_target_g >= 0), targets_are_estimated boolean not null default true,
  onboarding_completed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.user_allergies (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  allergen_id uuid references public.allergens(id) on delete restrict, custom_name text, created_at timestamptz not null default now(),
  check ((allergen_id is null) <> (custom_name is null)), check (custom_name is null or char_length(trim(custom_name)) between 1 and 100)
);
create unique index user_allergies_known_unique on public.user_allergies(user_id, allergen_id) where allergen_id is not null;
create unique index user_allergies_custom_unique on public.user_allergies(user_id, lower(custom_name)) where custom_name is not null;

create table public.foods (
  id uuid primary key default gen_random_uuid(), name text not null check (char_length(trim(name)) between 1 and 150),
  category_id uuid references public.food_categories(id) on delete set null, serving_label text not null check (char_length(trim(serving_label)) between 1 and 100),
  calories_kcal numeric(8,2) not null check (calories_kcal >= 0), protein_g numeric(8,2) check (protein_g >= 0),
  carbs_g numeric(8,2) check (carbs_g >= 0), fat_g numeric(8,2) check (fat_g >= 0), fiber_g numeric(8,2) check (fiber_g >= 0),
  sugar_g numeric(8,2) check (sugar_g >= 0), sodium_mg numeric(8,2) check (sodium_mg >= 0), description text, source_name text,
  is_verified boolean not null default false, created_by_user_id uuid references auth.users(id) on delete cascade,
  visibility text not null default 'public' check (visibility in ('public', 'private')), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check ((created_by_user_id is null and visibility = 'public') or created_by_user_id is not null)
);
create index foods_category_idx on public.foods(category_id);
create index foods_name_idx on public.foods using gin (to_tsvector('simple', name));
create table public.food_allergens (food_id uuid not null references public.foods(id) on delete cascade, allergen_id uuid not null references public.allergens(id) on delete restrict, primary key(food_id, allergen_id));
create table public.food_diet_tags (food_id uuid not null references public.foods(id) on delete cascade, diet_tag_code text not null references public.diet_tags(code) on delete restrict, primary key(food_id, diet_tag_code));
create table public.user_favorites (user_id uuid not null references auth.users(id) on delete cascade, food_id uuid not null references public.foods(id) on delete cascade, created_at timestamptz not null default now(), primary key(user_id, food_id));
create table public.user_disliked_foods (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, food_id uuid references public.foods(id) on delete restrict,
  custom_name text, created_at timestamptz not null default now(), check ((food_id is null) <> (custom_name is null)), check (custom_name is null or char_length(trim(custom_name)) between 1 and 150)
);
create unique index user_disliked_foods_known_unique on public.user_disliked_foods(user_id, food_id) where food_id is not null;
create unique index user_disliked_foods_custom_unique on public.user_disliked_foods(user_id, lower(custom_name)) where custom_name is not null;

create table public.meal_entries (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  food_id uuid not null references public.foods(id) on delete restrict, meal_type_code text not null references public.meal_types(code),
  servings numeric(8,3) not null check (servings > 0), logged_at timestamptz not null, notes text check (notes is null or char_length(notes) <= 1000),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index meal_entries_user_logged_idx on public.meal_entries(user_id, logged_at desc);
create table public.meal_entry_nutrition (
  meal_entry_id uuid primary key references public.meal_entries(id) on delete cascade, calories_kcal numeric(10,2) not null check (calories_kcal >= 0),
  protein_g numeric(10,2), carbs_g numeric(10,2), fat_g numeric(10,2), fiber_g numeric(10,2), sugar_g numeric(10,2), sodium_mg numeric(10,2), captured_at timestamptz not null default now()
);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
create trigger user_profiles_updated_at before update on public.user_profiles for each row execute function public.set_updated_at();
create trigger foods_updated_at before update on public.foods for each row execute function public.set_updated_at();
create trigger meal_entries_updated_at before update on public.meal_entries for each row execute function public.set_updated_at();

-- Atomic, trusted nutrition calculation. App clients never submit totals.
create or replace function public.create_meal_entry(p_food_id uuid, p_meal_type_code text, p_servings numeric, p_logged_at timestamptz, p_notes text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_food public.foods; v_entry_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_servings <= 0 then raise exception 'Servings must be greater than zero'; end if;
  select * into v_food from public.foods where id = p_food_id and (visibility = 'public' or created_by_user_id = auth.uid());
  if not found then raise exception 'Food not found or unavailable'; end if;
  insert into public.meal_entries(user_id,food_id,meal_type_code,servings,logged_at,notes) values(auth.uid(),p_food_id,p_meal_type_code,p_servings,p_logged_at,p_notes) returning id into v_entry_id;
  insert into public.meal_entry_nutrition(meal_entry_id,calories_kcal,protein_g,carbs_g,fat_g,fiber_g,sugar_g,sodium_mg)
  values(v_entry_id,v_food.calories_kcal*p_servings,v_food.protein_g*p_servings,v_food.carbs_g*p_servings,v_food.fat_g*p_servings,v_food.fiber_g*p_servings,v_food.sugar_g*p_servings,v_food.sodium_mg*p_servings);
  return v_entry_id;
end; $$;

alter table public.goals enable row level security; alter table public.activity_levels enable row level security; alter table public.diet_preferences enable row level security; alter table public.food_categories enable row level security; alter table public.diet_tags enable row level security; alter table public.allergens enable row level security; alter table public.meal_types enable row level security;
alter table public.user_profiles enable row level security; alter table public.user_allergies enable row level security; alter table public.foods enable row level security; alter table public.food_allergens enable row level security; alter table public.food_diet_tags enable row level security; alter table public.user_favorites enable row level security; alter table public.user_disliked_foods enable row level security; alter table public.meal_entries enable row level security; alter table public.meal_entry_nutrition enable row level security;
create policy "read goals" on public.goals for select to authenticated using(true); create policy "read activities" on public.activity_levels for select to authenticated using(true); create policy "read diets" on public.diet_preferences for select to authenticated using(true); create policy "read categories" on public.food_categories for select to authenticated using(true); create policy "read tags" on public.diet_tags for select to authenticated using(true); create policy "read allergens" on public.allergens for select to authenticated using(true); create policy "read meal types" on public.meal_types for select to authenticated using(true);
create policy "own profile" on public.user_profiles for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid()); create policy "own allergies" on public.user_allergies for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid()); create policy "read visible foods" on public.foods for select to authenticated using(visibility='public' or created_by_user_id=auth.uid());
create policy "create private foods" on public.foods for insert to authenticated with check(created_by_user_id=auth.uid() and visibility='private'); create policy "manage private foods" on public.foods for update to authenticated using(created_by_user_id=auth.uid() and visibility='private') with check(created_by_user_id=auth.uid() and visibility='private'); create policy "delete private foods" on public.foods for delete to authenticated using(created_by_user_id=auth.uid() and visibility='private');
create policy "read visible food allergens" on public.food_allergens for select to authenticated using(exists(select 1 from public.foods f where f.id=food_id and (f.visibility='public' or f.created_by_user_id=auth.uid()))); create policy "read visible food tags" on public.food_diet_tags for select to authenticated using(exists(select 1 from public.foods f where f.id=food_id and (f.visibility='public' or f.created_by_user_id=auth.uid())));
create policy "own favorites" on public.user_favorites for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid()); create policy "own dislikes" on public.user_disliked_foods for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid()); create policy "read own entries" on public.meal_entries for select to authenticated using(user_id=auth.uid()); create policy "delete own entries" on public.meal_entries for delete to authenticated using(user_id=auth.uid()); create policy "read own snapshots" on public.meal_entry_nutrition for select to authenticated using(exists(select 1 from public.meal_entries e where e.id=meal_entry_id and e.user_id=auth.uid()));

revoke all on function public.create_meal_entry(uuid, text, numeric, timestamptz, text) from public;
grant execute on function public.create_meal_entry(uuid, text, numeric, timestamptz, text) to authenticated;

insert into public.goals values ('muscle','Build muscle'),('weight_loss','Manage weight'),('weight_gain','Gain weight'),('balanced','Balanced diet'),('fiber','More fiber');
insert into public.activity_levels values ('sedentary','Sedentary',1.2),('light','Lightly active',1.375),('moderate','Moderately active',1.55),('active','Very active',1.725);
insert into public.diet_preferences values ('none','No preference'),('vegetarian','Vegetarian'),('vegan','Vegan'),('pescatarian','Pescatarian'); insert into public.diet_tags values ('vegan','Vegan'),('vegetarian','Vegetarian'),('pescatarian','Pescatarian'); insert into public.meal_types values ('breakfast','Breakfast'),('lunch','Lunch'),('dinner','Dinner'),('snack','Snack');
insert into public.allergens(code,display_name) values ('egg','Egg'),('milk','Milk'),('peanut','Peanut'),('soy','Soy'),('fish','Fish'),('shellfish','Shellfish'),('wheat','Wheat'),('tree_nuts','Tree nuts');
insert into public.food_categories(code,display_name) values ('protein','Protein'),('grains','Grains'),('fruit','Fruit'),('vegetables','Vegetables'),('legumes','Legumes'),('spreads','Spreads'),('dairy','Dairy'),('filipino','Filipino'),('salads','Salads'),('custom','Custom');
