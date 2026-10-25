-- Initial schema only. Review and test in a new Supabase project before production.
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
 primary key (workspace_id,user_id)
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
 content_id uuid not null references public.content_items(id) on delete cascade,
 content_version integer not null,
 approved_by uuid not null references auth.users(id) on delete restrict,
 approved_at timestamptz not null default now(),
 approved_payload jsonb not null,
 revoked_at timestamptz,
 revocation_reason text
);

create table public.publishing_jobs (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 content_id uuid not null references public.content_items(id) on delete cascade,
 content_version integer not null,
 approval_id uuid not null references public.approval_records(id) on delete restrict,
 destination text not null,
 scheduled_at timestamptz,
 status text not null default 'queued' check (status in ('queued','processing','published','failed','cancelled')),
 created_at timestamptz not null default now()
);

create table public.analytics_snapshots (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 content_id uuid not null references public.content_items(id) on delete cascade,
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
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.workspace_members m where m.workspace_id = target_workspace and m.user_id = auth.uid()) $$;

create or replace function public.is_workspace_owner(target_workspace uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.workspace_members m where m.workspace_id = target_workspace and m.user_id = auth.uid() and m.role = 'owner') $$;

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.content_items enable row level security;
alter table public.approval_records enable row level security;
alter table public.publishing_jobs enable row level security;
alter table public.analytics_snapshots enable row level security;
alter table public.audit_log enable row level security;

create policy "members can view their workspaces" on public.workspaces for select using (public.is_workspace_member(id));
create policy "owners can update workspaces" on public.workspaces for update using (public.is_workspace_owner(id)) with check (public.is_workspace_owner(id));
create policy "members can view workspace membership" on public.workspace_members for select using (public.is_workspace_member(workspace_id));
create policy "owners manage workspace membership" on public.workspace_members for all using (public.is_workspace_owner(workspace_id)) with check (public.is_workspace_owner(workspace_id));
create policy "members view content" on public.content_items for select using (public.is_workspace_member(workspace_id));
create policy "members create content" on public.content_items for insert with check (public.is_workspace_member(workspace_id) and created_by = auth.uid());
create policy "members update content" on public.content_items for update using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));
create policy "members view approvals" on public.approval_records for select using (public.is_workspace_member(workspace_id));
create policy "owners create approvals" on public.approval_records for insert with check (public.is_workspace_owner(workspace_id) and approved_by = auth.uid());
create policy "members view publishing jobs" on public.publishing_jobs for select using (public.is_workspace_member(workspace_id));
create policy "owners manage publishing jobs" on public.publishing_jobs for all using (public.is_workspace_owner(workspace_id)) with check (public.is_workspace_owner(workspace_id));
create policy "members view analytics" on public.analytics_snapshots for select using (public.is_workspace_member(workspace_id));
create policy "members view audit log" on public.audit_log for select using (public.is_workspace_member(workspace_id));

-- IMPORTANT: This is a starting schema, not production-certified. Approval integrity must be enforced by trusted server-side code/RPC and tested. Never rely on client UI alone to authorize publishing. Add immutability triggers and revoke/reapproval behavior before production.
