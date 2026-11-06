-- Run in Supabase SQL Editor as project owner. Enable email auth in Authentication settings.
create extension if not exists pgcrypto;
create table if not exists public.coaching_teams (
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 100),
 invite_code text unique not null default encode(gen_random_bytes(18),'hex'),
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now());
create table if not exists public.coaching_members (
 team_id uuid not null references public.coaching_teams(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check(role in ('owner','coach')) default 'coach',
 primary key(team_id,user_id));
create table if not exists public.coaching_snapshots (
 team_id uuid primary key references public.coaching_teams(id) on delete cascade,
 payload jsonb not null, version bigint not null default 1,
 updated_at timestamptz not null default now(), updated_by uuid references auth.users(id));
create index if not exists coaching_members_user_idx on public.coaching_members(user_id);
alter table public.coaching_teams enable row level security;
alter table public.coaching_members enable row level security;
alter table public.coaching_snapshots enable row level security;
revoke all on public.coaching_teams,public.coaching_members,public.coaching_snapshots from anon;
grant select on public.coaching_teams,public.coaching_snapshots to authenticated;
create policy "members view teams" on public.coaching_teams for select to authenticated using (
 exists(select 1 from public.coaching_members m where m.team_id=id and m.user_id=(select auth.uid())));
create policy "members view snapshots" on public.coaching_snapshots for select to authenticated using (
 exists(select 1 from public.coaching_members m where m.team_id=coaching_snapshots.team_id and m.user_id=(select auth.uid())));
-- SECURITY DEFINER functions are the only write entry points. Search path fixed and EXECUTE restricted.
create or replace function public.create_coaching_team(team_name text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare t public.coaching_teams;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 if length(trim(team_name)) not between 1 and 100 then raise exception 'Invalid team name'; end if;
 insert into public.coaching_teams(name,created_by) values(trim(team_name),auth.uid()) returning * into t;
 insert into public.coaching_members(team_id,user_id,role) values(t.id,auth.uid(),'owner');
 return jsonb_build_object('team_id',t.id,'invite_code',t.invite_code);
end $$;
create or replace function public.join_coaching_team(join_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare tid uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 select id into tid from public.coaching_teams where invite_code=trim(join_code);
 if tid is null then raise exception 'Invalid invite code'; end if;
 insert into public.coaching_members(team_id,user_id,role) values(tid,auth.uid(),'coach') on conflict do nothing;
 return tid;
end $$;
create or replace function public.save_coaching_snapshot(p_team_id uuid,p_payload jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.coaching_members where team_id=p_team_id and user_id=auth.uid()) then
 raise exception 'Not a member of this team'; end if;
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or pg_column_size(p_payload)>3000000 then raise exception 'Invalid or oversized snapshot'; end if;
 insert into public.coaching_snapshots(team_id,payload,updated_by) values(p_team_id,p_payload,auth.uid())
 on conflict(team_id) do update set payload=excluded.payload,updated_by=excluded.updated_by,
 updated_at=now(),version=public.coaching_snapshots.version+1 returning version into v;
 return v;
end $$;
revoke all on function public.create_coaching_team(text),public.join_coaching_team(text),public.save_coaching_snapshot(uuid,jsonb) from public,anon;
grant execute on function public.create_coaching_team(text),public.join_coaching_team(text),public.save_coaching_snapshot(uuid,jsonb) to authenticated;
