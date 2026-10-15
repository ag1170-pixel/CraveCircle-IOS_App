-- CraveCircle schema on Homelab self-hosted Supabase.
-- Isolated from GGSApple public.profiles. Do not drop public.handle_new_user.

CREATE SCHEMA IF NOT EXISTS cravecircle;

GRANT USAGE ON SCHEMA cravecircle TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS cravecircle.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    username text UNIQUE,
    full_name text,
    avatar_url text,
    role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'creator', 'admin')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cravecircle.recipes (
    id text PRIMARY KEY,
    owner_id uuid NOT NULL REFERENCES cravecircle.profiles (id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    prep_time text,
    cook_time text,
    servings int,
    ingredients jsonb NOT NULL DEFAULT '[]'::jsonb,
    directions jsonb NOT NULL DEFAULT '[]'::jsonb,
    thumbnail_url text,
    owner_username text,
    source_language text,
    nutrition jsonb,
    source_url text,
    visibility text NOT NULL DEFAULT 'everyone' CHECK (visibility IN ('everyone', 'followers')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cravecircle.follows (
    follower_id uuid NOT NULL REFERENCES cravecircle.profiles (id) ON DELETE CASCADE DEFAULT auth.uid(),
    creator_id uuid NOT NULL REFERENCES cravecircle.profiles (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, creator_id)
);

CREATE TABLE IF NOT EXISTS cravecircle.shares (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id text,
    from_user_id uuid NOT NULL REFERENCES cravecircle.profiles (id) ON DELETE CASCADE DEFAULT auth.uid(),
    to_user_id uuid NOT NULL REFERENCES cravecircle.profiles (id) ON DELETE CASCADE,
    channel text,
    recipe_title text,
    recipe_thumbnail text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cravecircle.user_interactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES cravecircle.profiles (id) ON DELETE CASCADE DEFAULT auth.uid(),
    recipe_id text NOT NULL,
    event_type text NOT NULL,
    duration_seconds int,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cravecircle.creator_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES cravecircle.profiles (id) ON DELETE CASCADE,
    social_platform text NOT NULL,
    social_handle text NOT NULL,
    social_url text,
    note text,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION cravecircle.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_touch ON cravecircle.profiles;
CREATE TRIGGER profiles_touch BEFORE UPDATE ON cravecircle.profiles
FOR EACH ROW EXECUTE FUNCTION cravecircle.touch_updated_at();

DROP TRIGGER IF EXISTS recipes_touch ON cravecircle.recipes;
CREATE TRIGGER recipes_touch BEFORE UPDATE ON cravecircle.recipes
FOR EACH ROW EXECUTE FUNCTION cravecircle.touch_updated_at();

-- Second trigger on auth.users — GGSApple public.handle_new_user stays.
CREATE OR REPLACE FUNCTION cravecircle.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle, public
AS $$
DECLARE
    handle text;
BEGIN
    handle := split_part(COALESCE(NEW.email, NEW.id::text), '@', 1);
    INSERT INTO cravecircle.profiles (id, username, full_name, avatar_url, role)
    VALUES (
        NEW.id,
        handle,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', handle),
        NEW.raw_user_meta_data->>'avatar_url',
        'user'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_cravecircle ON auth.users;
CREATE TRIGGER on_auth_user_created_cravecircle
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION cravecircle.handle_new_user();

CREATE OR REPLACE FUNCTION cravecircle.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = cravecircle
AS $$
    SELECT EXISTS (
        SELECT 1 FROM cravecircle.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
$$;

CREATE OR REPLACE FUNCTION cravecircle.log_interactions(p_events jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle
AS $$
DECLARE
    ev jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    FOR ev IN SELECT * FROM jsonb_array_elements(p_events)
    LOOP
        INSERT INTO cravecircle.user_interactions (user_id, recipe_id, event_type, duration_seconds)
        VALUES (
            auth.uid(),
            ev->>'recipeId',
            ev->>'eventType',
            NULLIF(ev->>'durationSeconds', '')::int
        );
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION cravecircle.get_suggested_recipes(p_limit int DEFAULT 12)
RETURNS SETOF cravecircle.recipes
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = cravecircle
AS $$
    SELECT *
    FROM cravecircle.recipes
    WHERE visibility = 'everyone'
    ORDER BY updated_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 12), 50));
$$;

CREATE OR REPLACE FUNCTION cravecircle.decide_creator_request(p_request_id uuid, p_approve boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle
AS $$
BEGIN
    IF NOT cravecircle.is_admin() THEN
        RAISE EXCEPTION 'not admin';
    END IF;
    UPDATE cravecircle.creator_requests
    SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END
    WHERE id = p_request_id;
    IF p_approve THEN
        UPDATE cravecircle.profiles
        SET role = 'creator'
        WHERE id = (SELECT user_id FROM cravecircle.creator_requests WHERE id = p_request_id);
    END IF;
END;
$$;

ALTER TABLE cravecircle.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE cravecircle.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE cravecircle.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE cravecircle.shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE cravecircle.user_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE cravecircle.creator_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select ON cravecircle.profiles;
CREATE POLICY profiles_select ON cravecircle.profiles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS profiles_update_own ON cravecircle.profiles;
CREATE POLICY profiles_update_own ON cravecircle.profiles
    FOR UPDATE USING (id = auth.uid());

DROP POLICY IF EXISTS recipes_select ON cravecircle.recipes;
CREATE POLICY recipes_select ON cravecircle.recipes
    FOR SELECT USING (
        visibility = 'everyone'
        OR owner_id = auth.uid()
        OR (
            visibility = 'followers'
            AND EXISTS (
                SELECT 1 FROM cravecircle.follows
                WHERE follower_id = auth.uid() AND creator_id = recipes.owner_id
            )
        )
    );

DROP POLICY IF EXISTS recipes_select_shared ON cravecircle.recipes;
CREATE POLICY recipes_select_shared ON cravecircle.recipes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM cravecircle.shares
            WHERE shares.recipe_id = recipes.id AND shares.to_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS recipes_write_own ON cravecircle.recipes;
CREATE POLICY recipes_write_own ON cravecircle.recipes
    FOR ALL USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS follows_own ON cravecircle.follows;
CREATE POLICY follows_own ON cravecircle.follows
    FOR ALL USING (follower_id = auth.uid()) WITH CHECK (follower_id = auth.uid());

DROP POLICY IF EXISTS shares_involved ON cravecircle.shares;
CREATE POLICY shares_involved ON cravecircle.shares
    FOR SELECT USING (from_user_id = auth.uid() OR to_user_id = auth.uid());

DROP POLICY IF EXISTS shares_insert ON cravecircle.shares;
CREATE POLICY shares_insert ON cravecircle.shares
    FOR INSERT WITH CHECK (from_user_id = auth.uid());

DROP POLICY IF EXISTS interactions_own ON cravecircle.user_interactions;
CREATE POLICY interactions_own ON cravecircle.user_interactions
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS creator_requests_own ON cravecircle.creator_requests;
CREATE POLICY creator_requests_own ON cravecircle.creator_requests
    FOR SELECT USING (user_id = auth.uid() OR cravecircle.is_admin());

DROP POLICY IF EXISTS creator_requests_insert ON cravecircle.creator_requests;
CREATE POLICY creator_requests_insert ON cravecircle.creator_requests
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS creator_requests_admin_update ON cravecircle.creator_requests;
CREATE POLICY creator_requests_admin_update ON cravecircle.creator_requests
    FOR UPDATE USING (cravecircle.is_admin());

GRANT SELECT ON cravecircle.profiles TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON cravecircle.profiles TO authenticated;
GRANT SELECT ON cravecircle.recipes TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON cravecircle.recipes TO authenticated;
-- anon needs SELECT on follows because recipes_select's RLS policy references it (planner checks
-- table privileges even though follows' own RLS still returns zero rows to anon). Without this,
-- anon/guest reads of cravecircle.recipes fail with "permission denied for table follows".
GRANT SELECT ON cravecircle.follows TO anon, authenticated;
GRANT INSERT, DELETE ON cravecircle.follows TO authenticated;
GRANT SELECT, INSERT ON cravecircle.shares TO authenticated;
GRANT SELECT, INSERT ON cravecircle.user_interactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON cravecircle.creator_requests TO authenticated;

GRANT EXECUTE ON FUNCTION cravecircle.log_interactions(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION cravecircle.get_suggested_recipes(int) TO authenticated;
GRANT EXECUTE ON FUNCTION cravecircle.decide_creator_request(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION cravecircle.is_admin() TO authenticated;

NOTIFY pgrst, 'reload schema';
