-- likes_and_saves.sql
--
-- Likes and Saves are currently device-only. A user signing in on a new device sees nothing
-- they previously liked or saved — and user A can't see the aggregate like-count on a public
-- recipe. This migration adds server-side tables, RLS, and a tiny count view so both the
-- cross-device roundtrip and the "N likes" number become real.
--
-- Deploy: `psql ... < supabase/likes_and_saves.sql`. Idempotent.

SET search_path = cravecircle, public;

-- 1. recipe_likes  — one row per (user, recipe). PK prevents duplicates.
CREATE TABLE IF NOT EXISTS cravecircle.recipe_likes (
    user_id    uuid        NOT NULL REFERENCES cravecircle.profiles(id) ON DELETE CASCADE,
    recipe_id  text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, recipe_id)
);

CREATE INDEX IF NOT EXISTS recipe_likes_by_recipe
    ON cravecircle.recipe_likes (recipe_id);

CREATE INDEX IF NOT EXISTS recipe_likes_by_user
    ON cravecircle.recipe_likes (user_id, created_at DESC);

ALTER TABLE cravecircle.recipe_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS recipe_likes_select ON cravecircle.recipe_likes;
CREATE POLICY recipe_likes_select ON cravecircle.recipe_likes
    FOR SELECT USING (true);  -- public read; the aggregate count is for everyone

DROP POLICY IF EXISTS recipe_likes_insert_own ON cravecircle.recipe_likes;
CREATE POLICY recipe_likes_insert_own ON cravecircle.recipe_likes
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS recipe_likes_delete_own ON cravecircle.recipe_likes;
CREATE POLICY recipe_likes_delete_own ON cravecircle.recipe_likes
    FOR DELETE USING (user_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON cravecircle.recipe_likes TO authenticated;
GRANT SELECT ON cravecircle.recipe_likes TO anon;

-- 2. recipe_saves (bookmarks) — private per user. Only the owner reads their own saves.
CREATE TABLE IF NOT EXISTS cravecircle.recipe_saves (
    user_id    uuid        NOT NULL REFERENCES cravecircle.profiles(id) ON DELETE CASCADE,
    recipe_id  text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, recipe_id)
);

CREATE INDEX IF NOT EXISTS recipe_saves_by_user
    ON cravecircle.recipe_saves (user_id, created_at DESC);

ALTER TABLE cravecircle.recipe_saves ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS recipe_saves_select_own ON cravecircle.recipe_saves;
CREATE POLICY recipe_saves_select_own ON cravecircle.recipe_saves
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS recipe_saves_insert_own ON cravecircle.recipe_saves;
CREATE POLICY recipe_saves_insert_own ON cravecircle.recipe_saves
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS recipe_saves_delete_own ON cravecircle.recipe_saves;
CREATE POLICY recipe_saves_delete_own ON cravecircle.recipe_saves
    FOR DELETE USING (user_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON cravecircle.recipe_saves TO authenticated;

-- 3. recipe_like_counts  — one row per recipe with a live count. Cheap SELECT for cards.
CREATE OR REPLACE VIEW cravecircle.recipe_like_counts AS
    SELECT recipe_id, count(*)::bigint AS likes
      FROM cravecircle.recipe_likes
     GROUP BY recipe_id;

GRANT SELECT ON cravecircle.recipe_like_counts TO authenticated, anon;

-- 4. follower_counts  — same pattern for the Studio stats row. Bonus: unblocks the real
-- Followers tile that was hidden earlier for lying "0".
CREATE OR REPLACE VIEW cravecircle.follower_counts AS
    SELECT creator_id AS user_id, count(*)::bigint AS followers
      FROM cravecircle.follows
     GROUP BY creator_id;

GRANT SELECT ON cravecircle.follower_counts TO authenticated, anon;

-- 5. my_likes_recent / my_saves_recent  — convenience RPCs so the iOS client can hydrate the
-- local sets at launch with one call instead of two SELECTs. Returns most-recent first.
CREATE OR REPLACE FUNCTION cravecircle.my_likes_recent(p_limit int DEFAULT 500)
RETURNS TABLE (recipe_id text, created_at timestamptz)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = cravecircle, public
AS $$
    SELECT recipe_id, created_at
      FROM cravecircle.recipe_likes
     WHERE user_id = auth.uid()
     ORDER BY created_at DESC
     LIMIT greatest(1, least(p_limit, 2000));
$$;

CREATE OR REPLACE FUNCTION cravecircle.my_saves_recent(p_limit int DEFAULT 500)
RETURNS TABLE (recipe_id text, created_at timestamptz)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = cravecircle, public
AS $$
    SELECT recipe_id, created_at
      FROM cravecircle.recipe_saves
     WHERE user_id = auth.uid()
     ORDER BY created_at DESC
     LIMIT greatest(1, least(p_limit, 2000));
$$;

GRANT EXECUTE ON FUNCTION cravecircle.my_likes_recent(int) TO authenticated;
GRANT EXECUTE ON FUNCTION cravecircle.my_saves_recent(int) TO authenticated;
