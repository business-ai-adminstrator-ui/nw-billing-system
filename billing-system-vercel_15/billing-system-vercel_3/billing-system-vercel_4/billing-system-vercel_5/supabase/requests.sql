-- Request PI (run once in Supabase -> SQL Editor). Needs open.sql style open access (no login).
create table if not exists public.bs_requests(
  id bigint generated always as identity primary key,
  company text not null,
  pax int not null check (pax>0),
  price numeric(12,2) not null check (price>=0),
  status text not null default 'pending_issue' check (status in ('pending_issue','pending_send','done')),
  requested_by text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now());
alter table public.bs_requests enable row level security;
drop policy if exists open_all on public.bs_requests;
create policy open_all on public.bs_requests for all to anon using (true) with check (true);
drop policy if exists req_auth on public.bs_requests;
create policy req_auth on public.bs_requests for all to authenticated using (true) with check (true);
do $$ begin begin alter publication supabase_realtime add table public.bs_requests; exception when others then null; end; end $$;
