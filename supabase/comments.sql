-- Shared recipe comments. Apply on the homelab database; the app cannot create the table.
CREATE TABLE IF NOT EXISTS cravecircle.comments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id text NOT NULL,
    author_id uuid NOT NULL DEFAULT auth.uid() REFERENCES cravecircle.profiles (id) ON DELETE CASCADE,
    author_name text NOT NULL,
    author_username text NOT NULL,
    body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS comments_recipe_created ON cravecircle.comments (recipe_id, created_at DESC);

ALTER TABLE cravecircle.comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS comments_read ON cravecircle.comments;
CREATE POLICY comments_read ON cravecircle.comments
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS comments_insert_own ON cravecircle.comments;
CREATE POLICY comments_insert_own ON cravecircle.comments
    FOR INSERT TO authenticated
    WITH CHECK (author_id = auth.uid());

GRANT SELECT, INSERT ON cravecircle.comments TO authenticated;

NOTIFY pgrst, 'reload schema';
