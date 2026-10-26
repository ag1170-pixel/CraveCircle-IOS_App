-- role_self_elevation.sql
--
-- Problem: `profiles_update_own` lets a user update any column on their own row — including
-- `role`. Without extra guardrails anyone can PATCH themselves to admin. The client-side
-- `elevateFounderIfMatches` relies on being able to set `role = admin`, but ONLY for the
-- founder email. This migration moves that check to the server so it isn't bypassable.
--
-- Rules this adds:
--   * A trigger on `cravecircle.profiles` rejects any UPDATE that changes `role` unless:
--       - the caller already is admin (admins can promote / demote), OR
--       - the caller IS the founder (identified by the auth email), setting themselves to admin.
--   * A grant-friendly SQL function `founder_elevate_me()` the iOS client calls on sign-in; it
--     flips the caller to admin iff their auth email matches the founder constant.
--
-- Deploy: `psql $SUPABASE_URL < supabase/role_self_elevation.sql` (or run the file inside the
-- Supabase SQL editor). Idempotent — safe to re-run.
--
-- To rotate the founder email, change `FOUNDER_EMAIL` in the function body and re-apply.

SET search_path = cravecircle, public;

-- 1. Trigger that blocks unauthorised role changes.
CREATE OR REPLACE FUNCTION cravecircle.enforce_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle, public
AS $$
DECLARE
    caller_email text;
    caller_role  text;
    founder_email text := 'adityagupta2646@gmail.com';
BEGIN
    IF NEW.role IS NOT DISTINCT FROM OLD.role THEN
        RETURN NEW;
    END IF;

    -- Who's calling?
    caller_email := lower(coalesce(auth.jwt() ->> 'email', ''));
    SELECT role::text INTO caller_role
      FROM cravecircle.profiles
     WHERE id = auth.uid();

    IF caller_role = 'admin' THEN
        RETURN NEW;
    END IF;

    IF caller_email = founder_email AND NEW.role = 'admin' AND NEW.id = auth.uid() THEN
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'role change not permitted'
        USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS enforce_role_change ON cravecircle.profiles;
CREATE TRIGGER enforce_role_change
    BEFORE UPDATE OF role ON cravecircle.profiles
    FOR EACH ROW EXECUTE FUNCTION cravecircle.enforce_role_change();

-- 2. Convenience RPC so the client can self-elevate without a bare PATCH call.
CREATE OR REPLACE FUNCTION cravecircle.founder_elevate_me()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = cravecircle, public
AS $$
DECLARE
    caller_email text;
    founder_email text := 'adityagupta2646@gmail.com';
BEGIN
    caller_email := lower(coalesce(auth.jwt() ->> 'email', ''));
    IF caller_email <> founder_email THEN
        RETURN false;
    END IF;

    UPDATE cravecircle.profiles
       SET role = 'admin'
     WHERE id = auth.uid()
       AND role IS DISTINCT FROM 'admin';

    RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION cravecircle.founder_elevate_me() TO authenticated;
