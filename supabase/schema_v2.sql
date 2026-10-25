-- Beyond the Known: initial secure database foundation
-- Apply only to a NEW/EMPTY Supabase project. This creates tables but does not enable publishing.
-- Publishing must remain disabled until a trusted server-side approval/version check is implemented.

create extension if not exists pgcrypto;

create type public.workspace_role as enum ('owner','editor','reviewer');
create type public.content_status as enum ('idea','research','script','production','review','approved','scheduled','published','rejected');

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Beyond the Known',
  created_at timestamptz not null default now()
);

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.workspace_role not null default 'editor',
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table public.content_items (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  title text not null,
  language text not null check (language in ('ar','en')),
  topic text,
  script text not null default '',
  caption text not null default '',
  video_url text,
  destination text[] not null default '{}',
  status public.content_status not null default 'idea',
  version integer not null default 1 check (version > 0),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.approval_records (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete restrict,
  content_version integer not null check (content_version > 0),
  approved_by uuid not null references auth.users(id) on delete restrict,
  approved_at timestamptz not null default now(),
  approved_payload jsonb not null,
  revoked_at timestamptz,
  revocation_reason text
);

create table public.publishing_jobs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete restrict,
  content_version integer not null check (content_version > 0),
  approval_id uuid not null references public.approval_records(id) on delete restrict,
  destination text not null,
  scheduled_at timestamptz,
  status text not null default 'queued' check (status in ('queued','processing','published','failed','cancelled')),
  created_at timestamptz not null default now()
);

create table public.analytics_snapshots (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete restrict,
  destination text not null,
  captured_at timestamptz not null default now(),
  metrics jsonb not null default '{}'::jsonb
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_workspace_member(target_workspace uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.workspace_members m
    where m.workspace_id = target_workspace and m.user_id = (select auth.uid())
  );
$$;

create or replace function public.is_workspace_owner(target_workspace uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.workspace_members m
    where m.workspace_id = target_workspace
      and m.user_id = (select auth.uid())
      and m.role = 'owner'
  );
$$;

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.content_items enable row level security;
alter table public.approval_records enable row level security;
alter table public.publishing_jobs enable row level security;
alter table public.analytics_snapshots enable row level security;
alter table public.audit_log enable row level security;

-- No client-side insert/update/delete policies are granted for approvals, publishing jobs,
-- audit records, or workspace creation. Trusted server-side code must handle those operations.
create policy "members read workspaces" on public.workspaces
  for select to authenticated using (public.is_workspace_member(id));

create policy "owners update workspaces" on public.workspaces
  for update to authenticated using (public.is_workspace_owner(id))
  with check (public.is_workspace_owner(id));

create policy "members read memberships" on public.workspace_members
  for select to authenticated using (public.is_workspace_member(workspace_id));

create policy "members read content" on public.content_items
  for select to authenticated using (public.is_workspace_member(workspace_id));

create policy "members create content" on public.content_items
  for insert to authenticated
  with check (public.is_workspace_member(workspace_id) and created_by = (select auth.uid()));

create policy "members update content" on public.content_items
  for update to authenticated
  using (public.is_workspace_member(workspace_id))
  with check (public.is_workspace_member(workspace_id) and updated_by = (select auth.uid()));

create policy "members read approvals" on public.approval_records
  for select to authenticated using (public.is_workspace_member(workspace_id));

create policy "members read publishing jobs" on public.publishing_jobs
  for select to authenticated using (public.is_workspace_member(workspace_id));

create policy "members read analytics" on public.analytics_snapshots
  for select to authenticated using (public.is_workspace_member(workspace_id));

create policy "members read audit log" on public.audit_log
  for select to authenticated using (public.is_workspace_member(workspace_id));

-- Approval records are append-only for normal application clients: no client write policies.
-- Do not enable a publishing integration until server-side code verifies:
-- 1) the approval belongs to the exact content item and workspace;
-- 2) approved version and approved_payload exactly match the outgoing version/payload;
-- 3) no edits occurred after approval (any edit increments version and invalidates approval);
-- 4) the user explicitly approved the exact final artifact and destination.


-- Create the first workspace for the currently signed-in user.
-- Safe to call once after sign-up; it will not create duplicate memberships.
create or replace function public.create_my_workspace(workspace_name text default 'Beyond the Known')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_workspace_id uuid;
  current_user_id uuid := (select auth.uid());
begin
  if current_user_id is null then
    raise exception 'You must be signed in to create a workspace';
  end if;

  select m.workspace_id into new_workspace_id
  from public.workspace_members m
  where m.user_id = current_user_id and m.role = 'owner'
  order by m.created_at
  limit 1;

  if new_workspace_id is not null then
    return new_workspace_id;
  end if;

  insert into public.workspaces(name)
  values (coalesce(nullif(trim(workspace_name), ''), 'Beyond the Known'))
  returning id into new_workspace_id;

  insert into public.workspace_members(workspace_id, user_id, role)
  values (new_workspace_id, current_user_id, 'owner');

  return new_workspace_id;
end;
$$;

revoke all on function public.create_my_workspace(text) from public;
grant execute on function public.create_my_workspace(text) to authenticated;
