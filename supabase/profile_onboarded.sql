-- Server-authoritative "has this account finished onboarding" flag.
-- Set once by the app on first finish; read on every sign-in so a brand-new
-- device / fresh install for an existing id skips the first-run flow entirely.
-- Idempotent — safe to run more than once.

alter table cravecircle.profiles
    add column if not exists onboarded_at timestamptz;
