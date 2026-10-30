begin;

insert into auth.users (id, aud, role, email, encrypted_password)
values (
  '00000000-0000-4000-8000-000000000601',
  'authenticated',
  'authenticated',
  'timezone@example.test',
  ''
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000601', true);

do $$
begin
  if (select count(*) from public.current_day_bounds('Asia/Manila')) <> 1 then
    raise exception 'A valid reporting time zone was rejected';
  end if;
  if (select count(*) from public.weekly_nutrition('UTC')) <> 7 then
    raise exception 'weekly_nutrition did not accept a valid time zone';
  end if;
  if (
    select count(*)
    from public.nutrition_summary('UTC', null, null, 7)
  ) <> 7 then
    raise exception 'nutrition_summary did not accept a valid time zone';
  end if;

  begin
    perform *
    from public.current_day_bounds('Not/A_Timezone');
    raise exception 'An invalid time zone was accepted by current_day_bounds';
  exception
    when others then
      if sqlerrm = 'An invalid time zone was accepted by current_day_bounds' then
        raise;
      end if;
  end;

  begin
    perform *
    from public.weekly_nutrition('Not/A_Timezone');
    raise exception 'An invalid time zone was accepted by weekly_nutrition';
  exception
    when others then
      if sqlerrm = 'An invalid time zone was accepted by weekly_nutrition' then
        raise;
      end if;
  end;

  begin
    perform *
    from public.nutrition_summary('Not/A_Timezone', null, null, 7);
    raise exception 'An invalid time zone was accepted by nutrition_summary';
  exception
    when others then
      if sqlerrm = 'An invalid time zone was accepted by nutrition_summary' then
        raise;
      end if;
  end;
end;
$$;

rollback;
