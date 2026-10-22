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

CREATE OR REPLACE FUNCTION cravecircle.comment_is_blocked(p_body text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    padded text;
    word text;
    words text[] := ARRAY[
        'fuck','fucking','fucker','fucked','shit','bitch','bastard','asshole',
        'dick','cock','pussy','cunt','slut','whore','nigger','nigga','faggot',
        'retard','rape','rapist',
        'madarchod','behenchod','bhosdike','bhosdi','chutiya','chutiye','gandu',
        'randi','harami','muth','muthmar','mardu','lund','lauda','jhatu','gaand',
        'kill yourself','kys','muth mar'
    ];
BEGIN
    padded := ' ' || regexp_replace(lower(p_body), '[^a-z]+', ' ', 'g') || ' ';
    FOREACH word IN ARRAY words LOOP
        IF padded LIKE '% ' || word || ' %' THEN
            RETURN true;
        END IF;
    END LOOP;
    RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION cravecircle.reject_blocked_comment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF cravecircle.comment_is_blocked(NEW.body) THEN
        RAISE EXCEPTION 'comment not allowed' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS comments_block_abuse ON cravecircle.comments;
CREATE TRIGGER comments_block_abuse
    BEFORE INSERT OR UPDATE OF body ON cravecircle.comments
    FOR EACH ROW EXECUTE FUNCTION cravecircle.reject_blocked_comment();

NOTIFY pgrst, 'reload schema';
