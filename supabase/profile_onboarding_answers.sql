-- Onboarding answers that drive personalization — stored on the profile so a signed-in user
-- doesn't lose their recommender state when they install on a new phone.
--
--   preferred_cuisines  — feeds Home ranking + "trending in your cuisines" suggestions
--   goals               — long-term personalization hook (improve, tryNew, healthier, …)
--   recipe_sources      — which platforms the user imports from (influences import onboarding)
--   hear_about          — attribution; useful for Discover-side analytics
--
-- Nothing cascades off these; they are reference data for the client. All optional and
-- nullable so existing rows read as "no answers yet". Idempotent — safe to re-run.

SET search_path = cravecircle, public;

alter table cravecircle.profiles
    add column if not exists preferred_cuisines text[] not null default '{}',
    add column if not exists goals              text[] not null default '{}',
    add column if not exists recipe_sources     text[] not null default '{}',
    add column if not exists hear_about         text;
