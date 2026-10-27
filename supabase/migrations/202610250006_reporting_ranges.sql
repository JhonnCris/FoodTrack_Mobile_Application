-- Range reporting from immutable nutrition snapshots. A 31-day ceiling keeps
-- the public authenticated RPC bounded while still supporting a calendar month.
create or replace function public.nutrition_summary(
  p_timezone text,
  p_start_date date default null,
  p_end_date date default null,
  p_days integer default 7
)
returns table(day date, calories_kcal numeric, protein_g numeric, carbs_g numeric, fat_g numeric)
language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_start_date is null and p_end_date is null then
    if p_days not between 1 and 31 then
      raise exception 'Report date ranges must be between 1 and 31 days';
    end if;
    p_end_date := (now() at time zone p_timezone)::date;
    p_start_date := p_end_date - (p_days - 1);
  end if;
  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    raise exception 'A valid report date range is required';
  end if;
  if p_end_date - p_start_date > 30 then
    raise exception 'Report date ranges cannot exceed 31 days';
  end if;

  return query
  with days as (
    select generate_series(p_start_date, p_end_date, interval '1 day')::date as report_day
  ), totals as (
    select (e.logged_at at time zone p_timezone)::date as report_day,
      sum(n.calories_kcal) as calories_kcal,
      sum(n.protein_g) as protein_g,
      sum(n.carbs_g) as carbs_g,
      sum(n.fat_g) as fat_g
    from public.meal_entries e
    join public.meal_entry_nutrition n on n.meal_entry_id = e.id
    where e.user_id = auth.uid()
      and (e.logged_at at time zone p_timezone)::date between p_start_date and p_end_date
    group by 1
  )
  select d.report_day,
    coalesce(t.calories_kcal, 0), coalesce(t.protein_g, 0),
    coalesce(t.carbs_g, 0), coalesce(t.fat_g, 0)
  from days d left join totals t using (report_day)
  order by d.report_day;
end;
$$;

revoke all on function public.nutrition_summary(text, date, date, integer) from public;
grant execute on function public.nutrition_summary(text, date, date, integer) to authenticated;
