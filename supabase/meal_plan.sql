-- meal_plan.sql
--
-- One scheduled cook per row. Owner-only everything: a meal plan is private between the user
-- and themselves. If we add sharing / collaborative plans later, add a separate shared-plan
-- table rather than opening up this one.
--
-- Deploy: `psql ... < supabase/meal_plan.sql`. Idempotent.

SET search_path = cravecircle, public;

CREATE TABLE IF NOT EXISTS cravecircle.meal_plan (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES cravecircle.profiles(id) ON DELETE CASCADE,
    recipe_id   text        NOT NULL,
    when_ts     timestamptz NOT NULL,
    slot        text        NOT NULL CHECK (slot IN ('breakfast','lunch','dinner','snack')),
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS meal_plan_by_user_when
    ON cravecircle.meal_plan (user_id, when_ts);

ALTER TABLE cravecircle.meal_plan ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS meal_plan_select_own ON cravecircle.meal_plan;
CREATE POLICY meal_plan_select_own ON cravecircle.meal_plan
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS meal_plan_insert_own ON cravecircle.meal_plan;
CREATE POLICY meal_plan_insert_own ON cravecircle.meal_plan
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS meal_plan_delete_own ON cravecircle.meal_plan;
CREATE POLICY meal_plan_delete_own ON cravecircle.meal_plan
    FOR DELETE USING (user_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON cravecircle.meal_plan TO authenticated;

-- Clean up planned cooks on a recipe when the recipe itself is deleted. Not critical for correctness
-- (the planned row just dangles) but keeps the UI from showing an empty slot.
CREATE OR REPLACE FUNCTION cravecircle.cleanup_meal_plan_on_recipe_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle, public
AS $$
BEGIN
    DELETE FROM cravecircle.meal_plan WHERE recipe_id = OLD.id;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS cleanup_meal_plan_on_recipe_delete ON cravecircle.recipes;
CREATE TRIGGER cleanup_meal_plan_on_recipe_delete
    AFTER DELETE ON cravecircle.recipes
    FOR EACH ROW EXECUTE FUNCTION cravecircle.cleanup_meal_plan_on_recipe_delete();
