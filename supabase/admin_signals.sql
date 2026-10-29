-- Admin "Signals" view — ranked lists for the admin dashboard that show what the audience
-- is actually responding to. Three buckets:
--
--   top_liked   — most liked recipes (recipe_likes count desc)
--   top_saved   — most saved recipes (recipe_saves count desc)
--   top_viewed  — most viewed recipes (user_interactions count desc, event_type='view')
--
-- All in one RPC so the client makes a single round-trip. SECURITY DEFINER + admin check so
-- a non-admin PostgREST call to this function raises instead of leaking aggregates.

SET search_path = cravecircle, public;

create or replace function cravecircle.admin_signals(top_n int default 10)
returns jsonb
language plpgsql
security definer
set search_path = cravecircle, public
as $$
declare
    caller_role text;
    result      jsonb;
begin
    select role::text into caller_role from cravecircle.profiles where id = auth.uid();
    if coalesce(caller_role, '') <> 'admin' then
        raise exception 'admin only' using errcode = '42501';
    end if;

    with liked as (
        select r.id, r.title, coalesce(r.thumbnail_url, '') as thumbnail_url,
               coalesce(r.owner_username, '') as owner_username,
               count(l.recipe_id)::int as n
          from cravecircle.recipes r
          left join cravecircle.recipe_likes l on l.recipe_id = r.id
         group by r.id, r.title, r.thumbnail_url, r.owner_username
         order by n desc, r.title
         limit greatest(top_n, 1)
    ),
    saved as (
        select r.id, r.title, coalesce(r.thumbnail_url, '') as thumbnail_url,
               coalesce(r.owner_username, '') as owner_username,
               count(s.recipe_id)::int as n
          from cravecircle.recipes r
          left join cravecircle.recipe_saves s on s.recipe_id = r.id
         group by r.id, r.title, r.thumbnail_url, r.owner_username
         order by n desc, r.title
         limit greatest(top_n, 1)
    ),
    viewed as (
        select r.id, r.title, coalesce(r.thumbnail_url, '') as thumbnail_url,
               coalesce(r.owner_username, '') as owner_username,
               count(i.recipe_id)::int as n
          from cravecircle.recipes r
          left join cravecircle.user_interactions i
                 on i.recipe_id = r.id and i.event_type = 'view'
         group by r.id, r.title, r.thumbnail_url, r.owner_username
         order by n desc, r.title
         limit greatest(top_n, 1)
    )
    select jsonb_build_object(
        'top_liked',  coalesce((select jsonb_agg(to_jsonb(l))  from liked  l), '[]'::jsonb),
        'top_saved',  coalesce((select jsonb_agg(to_jsonb(s))  from saved  s), '[]'::jsonb),
        'top_viewed', coalesce((select jsonb_agg(to_jsonb(v))  from viewed v), '[]'::jsonb),
        'generated_at', now()
    )
    into result;

    return result;
end;
$$;

revoke all on function cravecircle.admin_signals(int) from public;
grant execute on function cravecircle.admin_signals(int) to authenticated;
