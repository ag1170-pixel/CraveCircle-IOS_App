-- Server-side guard: no account, including an admin, can flag an imported recipe as public.
-- An "imported" recipe is one with a non-empty source_url that doesn't belong to our own
-- domain, which is the same shape the client's `Recipe.staysOnThisPhone` uses (any
-- http(s) source_url outside cravecircle.cc). Original Studio recipes remain publishable.
--
-- Rejects on both INSERT and UPDATE so a modified client can't:
--   - insert a recipe with source_url=... and visibility='everyone', or
--   - insert as followers-only and then PATCH visibility='everyone'.
--
-- Idempotent. Safe to re-run.

SET search_path = cravecircle, public;

create or replace function cravecircle.enforce_no_publish_imports()
returns trigger
language plpgsql
security definer
set search_path = cravecircle, public
as $$
declare
    is_imported boolean;
begin
    -- Only care about rows being made public.
    if new.visibility is distinct from 'everyone' then
        return new;
    end if;

    -- An http(s) source_url outside cravecircle.cc marks the recipe as imported from somewhere
    -- else (Instagram, TikTok, YouTube, Facebook, Pinterest, any blog). cravecircle.cc links
    -- are our own share URLs, not imports.
    is_imported := (
        coalesce(new.source_url, '') ~* '^https?://'
        and new.source_url !~* '^https?://([a-z0-9-]+\.)*cravecircle\.cc(/|$|:)'
    ) or coalesce(new.source_url, '') ~* '^cravecircle://import/';

    if not is_imported then
        return new;
    end if;

    raise exception 'imported recipes cannot be published — create an original recipe in Studio instead'
        using errcode = '42501';
end;
$$;

drop trigger if exists enforce_no_publish_imports on cravecircle.recipes;
create trigger enforce_no_publish_imports
    before insert or update on cravecircle.recipes
    for each row
    execute function cravecircle.enforce_no_publish_imports();
