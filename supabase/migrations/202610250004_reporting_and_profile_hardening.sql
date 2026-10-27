-- Server-side reporting and safe profile allergy persistence helpers.
create or replace function public.weekly_nutrition(p_timezone text default 'Asia/Manila')
returns table(day date, calories_kcal numeric, protein_g numeric, carbs_g numeric, fat_g numeric)
language sql security invoker set search_path = '' as $$
  with days as (
    select generate_series((now() at time zone p_timezone)::date - 6,
      (now() at time zone p_timezone)::date, interval '1 day')::date as day
  ), totals as (
    select (e.logged_at at time zone p_timezone)::date as day,
      sum(n.calories_kcal) as calories_kcal, sum(n.protein_g) as protein_g,
      sum(n.carbs_g) as carbs_g, sum(n.fat_g) as fat_g
    from public.meal_entries e join public.meal_entry_nutrition n on n.meal_entry_id=e.id
    where e.user_id=auth.uid()
      and (e.logged_at at time zone p_timezone)::date between (now() at time zone p_timezone)::date - 6 and (now() at time zone p_timezone)::date
    group by 1
  ) select days.day, coalesce(totals.calories_kcal,0), coalesce(totals.protein_g,0),
      coalesce(totals.carbs_g,0), coalesce(totals.fat_g,0) from days left join totals using(day) order by day;
$$;
revoke all on function public.weekly_nutrition(text) from public;
grant execute on function public.weekly_nutrition(text) to authenticated;

create or replace function public.replace_user_allergies(p_known_codes text[], p_custom_names text[])
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.user_allergies where user_id=auth.uid();
  insert into public.user_allergies(user_id,allergen_id)
  select auth.uid(),a.id from public.allergens a where a.code=any(coalesce(p_known_codes,array[]::text[]));
  insert into public.user_allergies(user_id,custom_name)
  select auth.uid(),trim(x) from unnest(coalesce(p_custom_names,array[]::text[])) x where trim(x)<>'';
end; $$;
revoke all on function public.replace_user_allergies(text[],text[]) from public;
grant execute on function public.replace_user_allergies(text[],text[]) to authenticated;

create or replace function public.current_day_bounds(p_timezone text default 'Asia/Manila')
returns table(start_at timestamptz, end_at timestamptz)
language sql security invoker set search_path = '' as $$
  select ((now() at time zone p_timezone)::date::timestamp at time zone p_timezone),
    (((now() at time zone p_timezone)::date + 1)::timestamp at time zone p_timezone);
$$;
revoke all on function public.current_day_bounds(text) from public;
grant execute on function public.current_day_bounds(text) to authenticated;
