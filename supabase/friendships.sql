-- Policies for the live friendships table (requester_id / addressee_id).
ALTER TABLE cravecircle.friendships
    DROP CONSTRAINT IF EXISTS friendships_not_self;
ALTER TABLE cravecircle.friendships
    ADD CONSTRAINT friendships_not_self CHECK (requester_id <> addressee_id);

CREATE UNIQUE INDEX IF NOT EXISTS friendships_one_pair ON cravecircle.friendships (
    LEAST(requester_id, addressee_id),
    GREATEST(requester_id, addressee_id)
);

ALTER TABLE cravecircle.friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS friendships_read ON cravecircle.friendships;
CREATE POLICY friendships_read ON cravecircle.friendships
    FOR SELECT TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

DROP POLICY IF EXISTS friendships_insert ON cravecircle.friendships;
CREATE POLICY friendships_insert ON cravecircle.friendships
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = requester_id AND requester_id <> addressee_id);

DROP POLICY IF EXISTS friendships_accept ON cravecircle.friendships;
CREATE POLICY friendships_accept ON cravecircle.friendships
    FOR UPDATE TO authenticated
    USING (auth.uid() = addressee_id)
    WITH CHECK (auth.uid() = addressee_id AND status = 'accepted');

DROP POLICY IF EXISTS friendships_delete ON cravecircle.friendships;
CREATE POLICY friendships_delete ON cravecircle.friendships
    FOR DELETE TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON cravecircle.friendships TO authenticated;

NOTIFY pgrst, 'reload schema';
