-- Align the profile socials columns with what the iOS client sends.
-- The table already had `instagram_handle` + `tiktok_handle` (older UI). The client stores and
-- edits full URLs for all five platforms, so we add the matching *_url columns and backfill
-- from the old handle columns so nothing is lost. Idempotent.

SET search_path = cravecircle, public;

alter table cravecircle.profiles
    add column if not exists instagram_url text,
    add column if not exists tiktok_url    text;

-- Backfill: if a handle was set but no URL, treat the handle as a URL/handle string so the
-- new profile view still shows something. The client already accepts either shape in UI.
update cravecircle.profiles
   set instagram_url = instagram_handle
 where instagram_url is null
   and instagram_handle is not null
   and instagram_handle <> '';

update cravecircle.profiles
   set tiktok_url = tiktok_handle
 where tiktok_url is null
   and tiktok_handle is not null
   and tiktok_handle <> '';
