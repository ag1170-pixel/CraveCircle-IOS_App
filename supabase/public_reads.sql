-- public_reads.sql
--
-- Comments weren't visible to signed-out viewers (nor to users whose session had expired),
-- because the SELECT policy was `TO authenticated`. Instagram and every social app treats
-- comment threads as public reads — anyone who can see the recipe should see its comments.
-- Likes (the aggregate count) and like-counts view are the same case.
--
-- This migration broadens the SELECT policies to cover both roles. Writes stay owner-only
-- (handled by the earlier migrations' INSERT / DELETE policies, which this file does not touch).
--
-- Deploy: `psql ... < supabase/public_reads.sql`. Idempotent.

SET search_path = cravecircle, public;

-- Comments — anyone can read; only the author / recipe owner / admin can delete; only the
-- author can insert (DEFAULT auth.uid() + INSERT policy handle that).
DROP POLICY IF EXISTS comments_read ON cravecircle.comments;
CREATE POLICY comments_read ON cravecircle.comments
    FOR SELECT
    USING (true);

GRANT SELECT ON cravecircle.comments TO anon;

-- Likes — public read so the "N likes" count can go on cards without the viewer being signed
-- in. Inserts / deletes stay owner-only.
DROP POLICY IF EXISTS recipe_likes_select ON cravecircle.recipe_likes;
CREATE POLICY recipe_likes_select ON cravecircle.recipe_likes
    FOR SELECT
    USING (true);

-- Likes aggregate view + follower count view — both already SELECT-granted to anon by the
-- likes_and_saves.sql migration. Re-granted here for safety.
GRANT SELECT ON cravecircle.recipe_like_counts TO anon, authenticated;
GRANT SELECT ON cravecircle.follower_counts    TO anon, authenticated;
