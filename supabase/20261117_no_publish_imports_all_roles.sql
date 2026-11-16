-- Imported recipes are private-library material for every role, including the founder/admin.
-- Apply through the normal Supabase migration process; this file is intentionally not executed
-- by the iOS app. It supersedes the earlier admin exception in no_publish_imports.sql.

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
    if new.visibility is distinct from 'everyone' then
        return new;
    end if;

    -- External http(s) pages are imports. The app also writes a private provenance marker for
    -- camera/photo or server imports that have no source URL. Neither may enter the public feed.
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
