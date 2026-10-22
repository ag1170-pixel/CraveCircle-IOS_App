-- Missing-dish searches. One row per person per dish. The admin hears about it once 10 people ask.
CREATE TABLE IF NOT EXISTS cravecircle.search_requests (
    query_key text NOT NULL,
    user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES cravecircle.profiles (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (query_key, user_id)
);

CREATE TABLE IF NOT EXISTS cravecircle.admin_alerts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    kind text NOT NULL,
    query_key text NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    ask_count int NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (kind, query_key)
);

ALTER TABLE cravecircle.search_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE cravecircle.admin_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS search_requests_insert_own ON cravecircle.search_requests;
CREATE POLICY search_requests_insert_own ON cravecircle.search_requests
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS admin_alerts_read ON cravecircle.admin_alerts;
CREATE POLICY admin_alerts_read ON cravecircle.admin_alerts
    FOR SELECT TO authenticated
    USING (cravecircle.is_admin());

CREATE OR REPLACE FUNCTION cravecircle.note_search_miss(p_query text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle
AS $$
DECLARE
    key text;
    n int;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;
    key := lower(regexp_replace(trim(p_query), '\s+', ' ', 'g'));
    IF char_length(key) < 3 OR char_length(key) > 80 THEN
        RETURN;
    END IF;
    INSERT INTO cravecircle.search_requests (query_key, user_id)
    VALUES (key, auth.uid())
    ON CONFLICT (query_key, user_id) DO NOTHING;
    SELECT count(*) INTO n FROM cravecircle.search_requests WHERE query_key = key;
    IF n >= 10 THEN
        INSERT INTO cravecircle.admin_alerts (kind, query_key, title, message, ask_count)
        VALUES (
            'search_demand',
            key,
            'Recipe people are asking for',
            key || ' — ' || n || ' people searched for this',
            n
        )
        ON CONFLICT (kind, query_key) DO UPDATE
            SET ask_count = EXCLUDED.ask_count,
                message = EXCLUDED.message;
    END IF;
END;
$$;

GRANT SELECT ON cravecircle.admin_alerts TO authenticated;
GRANT EXECUTE ON FUNCTION cravecircle.note_search_miss(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
