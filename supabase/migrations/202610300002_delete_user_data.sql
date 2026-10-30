create or replace function public.delete_user_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  delete from public.meal_entries where user_id = p_user_id;
  delete from public.user_favorites where user_id = p_user_id;
  delete from public.user_allergies where user_id = p_user_id;
  delete from public.user_disliked_foods where user_id = p_user_id;
  delete from public.user_profiles where user_id = p_user_id;
  delete from public.recommendation_events where user_id = p_user_id;
  delete from public.foods where created_by_user_id = p_user_id;
end;
$$;

revoke all on function public.delete_user_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_user_data(uuid) to service_role;
