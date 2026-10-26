-- comment_moderation.sql
--
-- Community safety audit (2026-10-26). Three gaps:
--
--   1. Comments table has no DELETE policy — not even an author can delete their own comment,
--      and admins have no way to take down abusive content. Fixed with three policies:
--        * comments_delete_own          — author deletes their own comment (Instagram-style).
--        * comments_delete_recipe_owner — the recipe's owner can delete any comment on their own
--          recipe (same as Instagram's "author of the post can moderate the thread").
--        * comments_delete_admin        — admin can delete anything.
--
--   2. recipe_id in comments / recipe_likes / recipe_saves is `text` with no FK, so deleting a
--      recipe leaves orphan rows. Added `cleanup_recipe_dependents` trigger on recipes DELETE
--      that wipes the three dependent tables by recipe_id. Avoids silent zombie data.
--
--   3. shares.recipe_id has the same shape — same cleanup for them.
--
-- Deploy: `psql ... < supabase/comment_moderation.sql`. Idempotent.

SET search_path = cravecircle, public;

-- 1. Comment DELETE policies
DROP POLICY IF EXISTS comments_delete_own ON cravecircle.comments;
CREATE POLICY comments_delete_own ON cravecircle.comments
    FOR DELETE TO authenticated
    USING (author_id = auth.uid());

DROP POLICY IF EXISTS comments_delete_recipe_owner ON cravecircle.comments;
CREATE POLICY comments_delete_recipe_owner ON cravecircle.comments
    FOR DELETE TO authenticated
    USING (EXISTS (
        SELECT 1 FROM cravecircle.recipes
         WHERE recipes.id = comments.recipe_id
           AND recipes.owner_id = auth.uid()
    ));

DROP POLICY IF EXISTS comments_delete_admin ON cravecircle.comments;
CREATE POLICY comments_delete_admin ON cravecircle.comments
    FOR DELETE TO authenticated
    USING (EXISTS (
        SELECT 1 FROM cravecircle.profiles
         WHERE profiles.id = auth.uid()
           AND profiles.role = 'admin'
    ));

GRANT DELETE ON cravecircle.comments TO authenticated;

-- 2. Admins can take down any recipe (spam, duplicates, policy violations). Pre-existing policy
-- only lets the owner delete. Add an admin override.
DROP POLICY IF EXISTS recipes_delete_admin ON cravecircle.recipes;
CREATE POLICY recipes_delete_admin ON cravecircle.recipes
    FOR DELETE TO authenticated
    USING (EXISTS (
        SELECT 1 FROM cravecircle.profiles
         WHERE profiles.id = auth.uid()
           AND profiles.role = 'admin'
    ));

-- 3. Orphan cleanup trigger — fires AFTER recipes DELETE and wipes comments / likes / saves /
-- shares that referenced it by text id. (Those columns can't be FKs because web imports carry
-- client-side ids like "web-abc123" that aren't in recipes.id for guest-era rows.)
CREATE OR REPLACE FUNCTION cravecircle.cleanup_recipe_dependents()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle, public
AS $$
BEGIN
    DELETE FROM cravecircle.comments      WHERE recipe_id = OLD.id;
    DELETE FROM cravecircle.recipe_likes  WHERE recipe_id = OLD.id;
    DELETE FROM cravecircle.recipe_saves  WHERE recipe_id = OLD.id;
    DELETE FROM cravecircle.shares        WHERE recipe_id = OLD.id;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS cleanup_recipe_dependents ON cravecircle.recipes;
CREATE TRIGGER cleanup_recipe_dependents
    AFTER DELETE ON cravecircle.recipes
    FOR EACH ROW EXECUTE FUNCTION cravecircle.cleanup_recipe_dependents();

-- 4. Admin RPC for a nuclear remove-a-user — rare but needed when a bad actor needs to go. The
-- usual `delete_me` only works for self; this one is admin-only and takes a target id.
CREATE OR REPLACE FUNCTION cravecircle.admin_delete_user(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle, public, auth
AS $$
DECLARE
    caller_role text;
BEGIN
    SELECT role::text INTO caller_role
      FROM cravecircle.profiles
     WHERE id = auth.uid();
    IF caller_role <> 'admin' THEN
        RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
    END IF;
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'user id required' USING ERRCODE = '22004';
    END IF;

    -- Everything referencing the profile cascades via existing ON DELETE CASCADE on profiles.id.
    DELETE FROM auth.users WHERE id = p_user_id;
    RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION cravecircle.admin_delete_user(uuid) TO authenticated;
