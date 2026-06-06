-- ChoreQuest — Supabase schema for cross-phone sync (CQ-13)
--
-- This belongs to a PERSONAL, free ChoreQuest project only. It is unrelated to
-- any other database. Run it once in YOUR project:
--   Dashboard → SQL Editor → New query → paste this whole file → Run.
-- Then enable anonymous accounts:
--   Dashboard → Authentication → Sign In / Providers → "Anonymous sign-ins" → ON.
--
-- The app talks to this with the project URL + the publishable (anon) key only.
-- Never put the database password or service_role key in the app.

create extension if not exists pgcrypto;

-- ── Households & membership ──────────────────────────────────────────────────
create table if not exists public.households (
    id          uuid primary key default gen_random_uuid(),
    invite_code text unique not null,
    created_at  timestamptz not null default now()
);

create table if not exists public.household_members (
    household_id uuid not null references public.households(id) on delete cascade,
    user_id      uuid not null references auth.users(id) on delete cascade,
    created_at   timestamptz not null default now(),
    primary key (household_id, user_id)
);

-- ── Synced data (mirrors the SwiftData models; `uuid` is the app's stable id) ─
create table if not exists public.participants (
    uuid         uuid primary key,
    household_id uuid not null references public.households(id) on delete cascade,
    name         text not null default '',
    emoji        text not null default '🙂',
    color_hex    text not null default '#7C5CFF',
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    deleted_at   timestamptz
);

create table if not exists public.chores (
    uuid         uuid primary key,
    household_id uuid not null references public.households(id) on delete cascade,
    name         text not null default '',
    emoji        text not null default '✅',
    points       int  not null default 1,
    color_hex    text,
    is_archived  boolean not null default false,
    sort_order   int  not null default 0,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    deleted_at   timestamptz
);

create table if not exists public.completions (
    uuid             uuid primary key,
    household_id     uuid not null references public.households(id) on delete cascade,
    completed_at     timestamptz not null default now(),
    points_awarded   int  not null default 0,
    chore_name       text not null default '',
    chore_emoji      text not null default '✅',
    -- Deliberately NOT foreign keys, so sync ordering can never trip a constraint:
    participant_uuid uuid,
    chore_uuid       uuid,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    deleted_at       timestamptz
);

-- Pull-cursor indexes (the client pulls rows where updated_at > lastPulledAt).
create index if not exists participants_household_updated on public.participants (household_id, updated_at);
create index if not exists chores_household_updated       on public.chores       (household_id, updated_at);
create index if not exists completions_household_updated  on public.completions  (household_id, updated_at);

-- ── Last-write-wins guard ────────────────────────────────────────────────────
-- Every device pushes its full row set via upsert. Without this, a device still
-- holding a stale copy of a row could overwrite a newer change from the other
-- phone (e.g. silently undo a delete). On UPDATE, keep whichever version has the
-- newer updated_at; an older incoming row is ignored (no-op).
create or replace function public.lww_guard()
returns trigger language plpgsql as $$
begin
    if NEW.updated_at < OLD.updated_at then
        return OLD; -- incoming is stale → keep the existing (newer) row
    end if;
    return NEW;
end;
$$;

drop trigger if exists participants_lww on public.participants;
create trigger participants_lww before update on public.participants
    for each row execute function public.lww_guard();

drop trigger if exists chores_lww on public.chores;
create trigger chores_lww before update on public.chores
    for each row execute function public.lww_guard();

drop trigger if exists completions_lww on public.completions;
create trigger completions_lww before update on public.completions
    for each row execute function public.lww_guard();

-- ── Row Level Security ───────────────────────────────────────────────────────
alter table public.households        enable row level security;
alter table public.household_members enable row level security;
alter table public.participants      enable row level security;
alter table public.chores            enable row level security;
alter table public.completions       enable row level security;

-- Households the current (anonymous) user belongs to.
create or replace function public.current_user_household_ids()
returns setof uuid
language sql stable security definer set search_path = public as $$
    select household_id from public.household_members where user_id = auth.uid()
$$;

-- household_members: a user only ever sees/edits their own membership rows.
-- Read own memberships and leave a household. There is deliberately NO direct
-- INSERT policy: membership is only ever created by the SECURITY DEFINER
-- create_household()/join_household() RPCs (which validate the invite code), so
-- the only way in is via a valid code.
drop policy if exists "members_read_own" on public.household_members;
create policy "members_read_own" on public.household_members
    for select to authenticated using (user_id = auth.uid());
drop policy if exists "members_insert_own" on public.household_members; -- removed (RPC-only join)
drop policy if exists "members_delete_own" on public.household_members;
create policy "members_delete_own" on public.household_members
    for delete to authenticated using (user_id = auth.uid());

-- households: members can read theirs; any signed-in user may create one.
drop policy if exists "households_read_member" on public.households;
create policy "households_read_member" on public.households
    for select to authenticated using (id in (select public.current_user_household_ids()));
drop policy if exists "households_insert" on public.households;
create policy "households_insert" on public.households
    for insert to authenticated with check (true);

-- Data tables: read/write only within the caller's household(s).
drop policy if exists "participants_rw" on public.participants;
create policy "participants_rw" on public.participants for all to authenticated
    using      (household_id in (select public.current_user_household_ids()))
    with check (household_id in (select public.current_user_household_ids()));

drop policy if exists "chores_rw" on public.chores;
create policy "chores_rw" on public.chores for all to authenticated
    using      (household_id in (select public.current_user_household_ids()))
    with check (household_id in (select public.current_user_household_ids()));

drop policy if exists "completions_rw" on public.completions;
create policy "completions_rw" on public.completions for all to authenticated
    using      (household_id in (select public.current_user_household_ids()))
    with check (household_id in (select public.current_user_household_ids()));

-- ── Create / Join a household (called by the app via /rest/v1/rpc/...) ────────
create or replace function public.create_household()
returns public.households
language plpgsql security definer set search_path = public as $$
declare h public.households;
begin
    -- 8 hex chars (~32 bits) — short enough to share, large enough that brute
    -- forcing via join_household is impractical for this threat model.
    insert into public.households (invite_code)
        values (upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)))
        returning * into h;
    insert into public.household_members (household_id, user_id) values (h.id, auth.uid());
    return h;
end;
$$;

create or replace function public.join_household(code text)
returns public.households
language plpgsql security definer set search_path = public as $$
declare h public.households;
begin
    select * into h from public.households where invite_code = upper(trim(code));
    if h.id is null then
        raise exception 'No household found for that code';
    end if;
    insert into public.household_members (household_id, user_id)
        values (h.id, auth.uid())
        on conflict do nothing;
    return h;
end;
$$;

grant execute on function public.current_user_household_ids() to authenticated;
grant execute on function public.create_household()            to authenticated;
grant execute on function public.join_household(text)          to authenticated;
