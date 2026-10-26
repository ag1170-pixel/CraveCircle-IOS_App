-- delete_me.sql
--
-- App Store Guideline 5.1.1(v) requires any app that supports account creation to also offer
-- in-app account deletion that really deletes the account (not just a sign-out). The client
-- ships only the Supabase anon key — it can't call GoTrue admin APIs — so this migration adds
-- a SECURITY DEFINER RPC `delete_me()` that:
--
--   * wipes every `cravecircle.*` row owned by the caller (profile, recipes, follows out+in,
--     shares out+in, user_interactions, creator_requests, recipe_likes, recipe_saves,
--     comments if present),
--   * deletes the matching `auth.users` row so the account can't sign in again.
--
-- Caller: any authenticated user, deleting themselves. Returns true on success.
--
-- Deploy: `psql ... < supabase/delete_me.sql`. Idempotent.

SET search_path = cravecircle, public;

CREATE OR REPLACE FUNCTION cravecircle.delete_me()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle, public, auth
AS $$
DECLARE
    uid uuid := auth.uid();
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'no authenticated user'
            USING ERRCODE = '42501';
    END IF;

    -- Social edges in both directions.
    DELETE FROM cravecircle.follows WHERE follower_id = uid OR creator_id  = uid;
    DELETE FROM cravecircle.shares  WHERE from_user   = uid OR to_user     = uid;

    -- Content and bookmarks.
    DELETE FROM cravecircle.recipe_likes      WHERE user_id = uid;
    DELETE FROM cravecircle.recipe_saves      WHERE user_id = uid;
    DELETE FROM cravecircle.user_interactions WHERE user_id = uid;
    DELETE FROM cravecircle.creator_requests  WHERE user_id = uid;

    -- Comments the user wrote (table may or may not exist in this environment — guard).
    IF to_regclass('cravecircle.comments') IS NOT NULL THEN
        EXECUTE 'DELETE FROM cravecircle.comments WHERE author_id = $1' USING uid;
    END IF;

    -- Recipes the user owns. If `recipes.owner_id` has `ON DELETE CASCADE` for likes/saves,
    -- the above already cleaned those up; the recipe rows themselves are deleted here.
    DELETE FROM cravecircle.recipes WHERE owner_id = uid;

    -- Profile row.
    DELETE FROM cravecircle.profiles WHERE id = uid;

    -- Auth row — stops them from signing in again.
    DELETE FROM auth.users WHERE id = uid;

    RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION cravecircle.delete_me() TO authenticated;
