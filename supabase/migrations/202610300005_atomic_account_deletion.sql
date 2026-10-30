create or replace function public.cleanup_user_data_before_auth_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.meal_entries
  where user_id = old.id;

  delete from public.user_disliked_foods
  where user_id = old.id;

  return old;
end;
$$;

revoke all on function public.cleanup_user_data_before_auth_delete()
  from public, anon, authenticated;

create trigger foodtrack_cleanup_user_data_before_auth_delete
before delete on auth.users
for each row
execute function public.cleanup_user_data_before_auth_delete();

drop function public.delete_user_data(uuid);
