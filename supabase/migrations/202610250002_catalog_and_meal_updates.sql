-- Curated starter catalog. Values are per listed serving and remain unverified
-- until a nutrition source is recorded and reviewed.
alter table public.foods add column emoji text not null default '🍽️';

create or replace function public.update_meal_entry_servings(p_entry_id uuid, p_servings numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare v_food public.foods;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_servings <= 0 then raise exception 'Servings must be greater than zero'; end if;
  select f.* into v_food from public.meal_entries e join public.foods f on f.id=e.food_id
    where e.id=p_entry_id and e.user_id=auth.uid();
  if not found then raise exception 'Meal entry not found'; end if;
  update public.meal_entries set servings=p_servings where id=p_entry_id and user_id=auth.uid();
  update public.meal_entry_nutrition set calories_kcal=v_food.calories_kcal*p_servings,
    protein_g=v_food.protein_g*p_servings, carbs_g=v_food.carbs_g*p_servings,
    fat_g=v_food.fat_g*p_servings, fiber_g=v_food.fiber_g*p_servings,
    sugar_g=v_food.sugar_g*p_servings, sodium_mg=v_food.sodium_mg*p_servings, captured_at=now()
    where meal_entry_id=p_entry_id;
end; $$;
revoke all on function public.update_meal_entry_servings(uuid, numeric) from public;
grant execute on function public.update_meal_entry_servings(uuid, numeric) to authenticated;

insert into public.foods(name,category_id,serving_label,calories_kcal,protein_g,carbs_g,fat_g,fiber_g,sugar_g,sodium_mg,description,source_name,emoji)
select v.name,c.id,v.serving,v.cal,v.pro,v.carb,v.fat,v.fiber,v.sugar,v.sodium,v.description,'FoodTrack starter catalog',v.emoji
from (values
 ('Boiled Egg','protein','1 large (50 g)',78,6.3,0.6,5.3,0,0,62,'A compact source of complete protein.','🥚'),
 ('Chicken Breast','protein','100 g cooked',165,31,0,3.6,0,0,74,'Lean protein for meals and recovery.','🍗'),
 ('Grilled Tilapia','protein','100 g cooked',128,26,0,2.7,0,0,56,'Light white fish, high in protein.','🐟'),
 ('Tofu','protein','100 g',76,8,1.9,4.8,0.3,0,0,'Plant-based protein.','🧈'),
 ('Cooked Rice','grains','1 cup (158 g)',205,4.3,45,0.4,0.6,0,0,'A staple, energy-dense carb source.','🍚'),
 ('Oatmeal','grains','1 cup cooked',154,6,27,3.2,4,0,0,'Slow-digesting carbs with beta-glucan fiber.','🥣'),
 ('Banana','fruit','1 medium',105,1.3,27,0.4,3.1,14,0,'Quick energy with potassium.','🍌'),
 ('Mango','fruit','1 cup sliced',99,1.4,25,0.6,2.6,23,0,'Rich in vitamin C and vitamin A.','🥭'),
 ('Steamed Broccoli','vegetables','1 cup (156 g)',55,3.7,11,0.6,5.1,2,64,'High fiber with vitamin C and vitamin K.','🥦'),
 ('Black Beans','legumes','1 cup cooked',227,15,41,0.9,15,0,0,'Fiber and plant protein in one serving.','🫘'),
 ('Peanut Butter','spreads','2 tbsp (32 g)',190,7,7,16,2,3,140,'Energy-dense and useful for weight gain.','🥜'),
 ('Whole Milk','dairy','1 cup (244 ml)',149,8,12,8,0,12,105,'Protein and calcium.','🥛'),
 ('Chicken Adobo','filipino','1 serving (150 g)',290,24,5,19,0,0,780,'Classic Filipino dish; high in sodium.','🍲'),
 ('Ginisang Monggo','filipino','1 cup',210,12,31,5,9,0,410,'Mung bean stew; preparation can vary.','🥣'),
 ('Garden Salad','salads','2 cups',75,3,12,2,4,0,0,'Mixed greens with light vinaigrette.','🥗'),
 ('Baked Salmon','protein','100 g',206,22,0,12,0,0,60,'Oily fish rich in protein and omega-3 fats.','🐟')
) as v(name,category,serving,cal,pro,carb,fat,fiber,sugar,sodium,description,emoji)
join public.food_categories c on c.code=v.category;

insert into public.food_allergens(food_id,allergen_id)
select f.id,a.id from public.foods f join public.allergens a on (f.name,a.code) in (
 ('Boiled Egg','egg'),('Grilled Tilapia','fish'),('Tofu','soy'),('Peanut Butter','peanut'),('Whole Milk','milk'),('Chicken Adobo','soy'),('Baked Salmon','fish')
);
insert into public.food_diet_tags(food_id,diet_tag_code)
select f.id,t.code from public.foods f join public.diet_tags t on
  (f.name in ('Tofu','Cooked Rice','Oatmeal','Banana','Mango','Steamed Broccoli','Black Beans','Peanut Butter','Ginisang Monggo','Garden Salad') and t.code in ('vegan','vegetarian','pescatarian'))
  or (f.name in ('Boiled Egg','Whole Milk') and t.code='vegetarian')
  or (f.name in ('Grilled Tilapia','Baked Salmon') and t.code='pescatarian');
