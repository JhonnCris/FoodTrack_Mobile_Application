revoke all on function public.create_meal_entry(uuid, text, numeric, timestamptz, text)
  from public, anon;
grant execute on function public.create_meal_entry(uuid, text, numeric, timestamptz, text)
  to authenticated;

revoke all on function public.update_meal_entry_servings(uuid, numeric)
  from public, anon;
grant execute on function public.update_meal_entry_servings(uuid, numeric)
  to authenticated;

revoke all on function public.weekly_nutrition(text)
  from public, anon;
grant execute on function public.weekly_nutrition(text)
  to authenticated;

revoke all on function public.replace_user_allergies(text[], text[])
  from public, anon;
grant execute on function public.replace_user_allergies(text[], text[])
  to authenticated;

revoke all on function public.current_day_bounds(text)
  from public, anon;
grant execute on function public.current_day_bounds(text)
  to authenticated;

revoke all on function public.nutrition_summary(text, date, date, integer)
  from public, anon;
grant execute on function public.nutrition_summary(text, date, date, integer)
  to authenticated;

revoke all on function public.save_user_profile(jsonb, text[], text[], text[])
  from public, anon;
grant execute on function public.save_user_profile(jsonb, text[], text[], text[])
  to authenticated;

revoke all on function public.record_recommendation_event(text, text, numeric, jsonb)
  from public, anon;
grant execute on function public.record_recommendation_event(text, text, numeric, jsonb)
  to authenticated;
