-- Public profile extensions used by Edit Profile + the public creator view.
-- Idempotent. Safe to re-run.
--
--   bio               — short line shown under the creator's name
--   pinterest_url     — fifth social; the other four are already present
--   verified          — admin-granted blue tick (NEVER user-settable)

SET search_path = cravecircle, public;

alter table cravecircle.profiles
    add column if not exists bio               text,
    add column if not exists pinterest_url     text,
    add column if not exists verified          boolean not null default false;

-- `verified` must stay admin-only. Trigger blocks a non-admin from flipping it.
create or replace function cravecircle.enforce_verified_admin_only()
returns trigger
language plpgsql
security definer
set search_path = cravecircle, public
as $$
declare
    caller_role text;
begin
    if new.verified is distinct from old.verified then
        select role::text into caller_role from cravecircle.profiles where id = auth.uid();
        if coalesce(caller_role, '') <> 'admin' then
            raise exception 'verified can only be changed by an admin' using errcode = '42501';
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists enforce_verified_admin_only on cravecircle.profiles;
create trigger enforce_verified_admin_only
    before update on cravecircle.profiles
    for each row
    execute function cravecircle.enforce_verified_admin_only();
