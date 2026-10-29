-- Content moderation: user-side reporting + admin-side account disable.
-- Idempotent. Safe to re-run.
--
--   profiles.disabled          — admin flips to true to block the account. The app treats a
--                                disabled profile as signed-out on bootstrap and refuses writes.
--
--   reports                    — anyone signed-in can file a report against a recipe, a
--                                comment, or another user. Admin reads the queue and acts.

SET search_path = cravecircle, public;

alter table cravecircle.profiles
    add column if not exists disabled boolean not null default false;

create table if not exists cravecircle.reports (
    id            uuid        primary key default gen_random_uuid(),
    reporter_id   uuid        not null references cravecircle.profiles(id) on delete cascade default auth.uid(),
    target_type   text        not null check (target_type in ('recipe', 'comment', 'user')),
    target_id     text        not null,          -- recipe/comment id (text) or user uuid as text
    reason        text        not null,          -- short categorical reason, e.g. 'spam', 'harassment'
    note          text,                          -- optional free text from the reporter
    status        text        not null default 'open' check (status in ('open', 'reviewing', 'closed')),
    created_at    timestamptz not null default now(),
    reviewed_at   timestamptz,
    reviewed_by   uuid references cravecircle.profiles(id) on delete set null
);

create index if not exists reports_status_idx  on cravecircle.reports (status, created_at desc);
create index if not exists reports_target_idx  on cravecircle.reports (target_type, target_id);

alter table cravecircle.reports enable row level security;

-- Anyone signed-in can file a report; one row per attempt (dedupe can live client-side).
drop policy if exists reports_insert_any on cravecircle.reports;
create policy reports_insert_any
    on cravecircle.reports for insert
    to authenticated
    with check (reporter_id = auth.uid());

-- Reporter can see their own reports; admin can see everything.
drop policy if exists reports_select_own_or_admin on cravecircle.reports;
create policy reports_select_own_or_admin
    on cravecircle.reports for select
    to authenticated
    using (
        reporter_id = auth.uid()
        or exists (select 1 from cravecircle.profiles p where p.id = auth.uid() and p.role = 'admin')
    );

-- Only admin can update (status transitions) or delete.
drop policy if exists reports_update_admin on cravecircle.reports;
create policy reports_update_admin
    on cravecircle.reports for update
    to authenticated
    using (exists (select 1 from cravecircle.profiles p where p.id = auth.uid() and p.role = 'admin'))
    with check (exists (select 1 from cravecircle.profiles p where p.id = auth.uid() and p.role = 'admin'));

drop policy if exists reports_delete_admin on cravecircle.reports;
create policy reports_delete_admin
    on cravecircle.reports for delete
    to authenticated
    using (exists (select 1 from cravecircle.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- `disabled` must stay admin-only. Same shape as the verified trigger.
create or replace function cravecircle.enforce_disabled_admin_only()
returns trigger
language plpgsql
security definer
set search_path = cravecircle, public
as $$
declare
    caller_role text;
begin
    if new.disabled is distinct from old.disabled then
        select role::text into caller_role from cravecircle.profiles where id = auth.uid();
        if coalesce(caller_role, '') <> 'admin' then
            raise exception 'disabled can only be changed by an admin' using errcode = '42501';
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists enforce_disabled_admin_only on cravecircle.profiles;
create trigger enforce_disabled_admin_only
    before update on cravecircle.profiles
    for each row
    execute function cravecircle.enforce_disabled_admin_only();
