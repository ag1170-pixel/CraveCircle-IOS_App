-- CraveCircle: capture the user's preferred recipe language on each import job,
-- so the pipeline can translate the transcribed recipe into it.
-- Apply on the Homelab Supabase Postgres (schema that owns import_jobs).

ALTER TABLE import_jobs
    ADD COLUMN IF NOT EXISTS target_language text;

-- Speeds up the worker's SKIP LOCKED claim query.
CREATE INDEX IF NOT EXISTS idx_import_jobs_status_created
    ON import_jobs (status, created_at);
