-- Billing System — Supabase schema (all objects prefixed bs_ so they never clash with other tables in your project)
-- (run once in Supabase → SQL Editor)
-- Roles: 'sales' and 'admin'. Permissions are enforced by Row Level Security,
-- so they hold even if someone opens the browser console.

create table if not exists public.bs_profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('sales','admin')),
  name text not null default '',
  created_at timestamptz not null default now());

create or replace function public.bs_my_role() returns text
language sql stable security definer set search_path=public as
$$ select role from public.bs_profiles where id=auth.uid() $$;

create table if not exists public.bs_docs(
  no text primary key,
  proj text not null, type text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  approved_by text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now());

create table if not exists public.bs_payments(
  id bigint generated always as identity primary key,
  doc_no text not null references public.bs_docs(no),
  amt numeric(12,2) not null check (amt>0),
  created_by uuid not null default auth.uid() references auth.users(id),
  data jsonb not null,
  created_at timestamptz not null default now());

create table if not exists public.bs_notifs(
  id bigint generated always as identity primary key,
  to_role text not null check (to_role in ('sales','admin')),
  to_user uuid references auth.users(id),
  doc_no text, kind text not null default '', text text not null,
  created_at timestamptz not null default now());

-- Guard: only admin may change approval fields; stamp update time.
create or replace function public.bs_docs_guard() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  new.created_by := old.created_by;
  new.no := old.no;
  if public.bs_my_role() <> 'admin' then
    new.approved_by := old.approved_by;
    if new.status = 'approved' then raise exception 'Only Admin can approve'; end if;
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists bs_docs_guard on public.bs_docs;
create trigger bs_docs_guard before update on public.bs_docs for each row execute function public.bs_docs_guard();

alter table public.bs_profiles enable row level security;
alter table public.bs_docs     enable row level security;
alter table public.bs_payments enable row level security;
alter table public.bs_notifs   enable row level security;

drop policy if exists p_self on public.bs_profiles;
create policy p_self on public.bs_profiles for select to authenticated
  using (id=auth.uid() or public.bs_my_role()='admin');

-- docs
drop policy if exists d_select on public.bs_docs;
create policy d_select on public.bs_docs for select to authenticated using (public.bs_my_role() in ('sales','admin'));
drop policy if exists d_insert on public.bs_docs;
create policy d_insert on public.bs_docs for insert to authenticated
  with check (created_by=auth.uid() and (public.bs_my_role()='admin' or (public.bs_my_role()='sales' and status='pending' and approved_by='')));
drop policy if exists d_update_admin on public.bs_docs;
create policy d_update_admin on public.bs_docs for update to authenticated
  using (public.bs_my_role()='admin') with check (public.bs_my_role()='admin');
drop policy if exists d_update_sales on public.bs_docs;
create policy d_update_sales on public.bs_docs for update to authenticated
  using (public.bs_my_role()='sales' and created_by=auth.uid() and status in ('pending','rejected'))
  with check (public.bs_my_role()='sales' and created_by=auth.uid() and status='pending');

-- payments (only on approved, non-quotation documents)
drop policy if exists pay_select on public.bs_payments;
create policy pay_select on public.bs_payments for select to authenticated using (public.bs_my_role() in ('sales','admin'));
drop policy if exists pay_insert on public.bs_payments;
create policy pay_insert on public.bs_payments for insert to authenticated
  with check (created_by=auth.uid() and public.bs_my_role() in ('sales','admin')
    and exists (select 1 from public.bs_docs d where d.no=doc_no and d.status='approved' and d.type<>'Q'));
drop policy if exists pay_update on public.bs_payments;
create policy pay_update on public.bs_payments for update to authenticated
  using (public.bs_my_role()='admin' or (public.bs_my_role()='sales' and created_by=auth.uid()))
  with check (public.bs_my_role()='admin' or (public.bs_my_role()='sales' and created_by=auth.uid()));

-- notifications
drop policy if exists n_select on public.bs_notifs;
create policy n_select on public.bs_notifs for select to authenticated
  using ((to_role='admin' and public.bs_my_role()='admin') or (to_user=auth.uid()));
drop policy if exists n_insert on public.bs_notifs;
create policy n_insert on public.bs_notifs for insert to authenticated
  with check (public.bs_my_role() in ('sales','admin'));

-- Realtime (instant admin alerts)
do $$ begin
  begin alter publication supabase_realtime add table public.bs_docs; exception when others then null; end;
  begin alter publication supabase_realtime add table public.bs_payments; exception when others then null; end;
  begin alter publication supabase_realtime add table public.bs_notifs; exception when others then null; end;
end $$;

-- Private storage bucket for proof-of-payment files
insert into storage.buckets(id,name,public,file_size_limit)
  values ('bs-proofs','bs-proofs',false,8388608) on conflict (id) do nothing;
drop policy if exists bs_proofs_read on storage.objects;
create policy bs_proofs_read on storage.objects for select to authenticated
  using (bucket_id='bs-proofs' and public.bs_my_role() in ('sales','admin'));
drop policy if exists bs_proofs_write on storage.objects;
create policy bs_proofs_write on storage.objects for insert to authenticated
  with check (bucket_id='bs-proofs' and public.bs_my_role() in ('sales','admin'));


drop policy if exists d_select on public.bs_docs;
create policy d_select on public.bs_docs for select to authenticated
  using (public.bs_my_role()='admin' or (public.bs_my_role()='sales' and created_by=auth.uid()));

drop policy if exists pay_select on public.bs_payments;
create policy pay_select on public.bs_payments for select to authenticated
  using (public.bs_my_role()='admin'
     or (public.bs_my_role()='sales' and (created_by=auth.uid()
         or exists (select 1 from public.bs_docs d where d.no=doc_no and d.created_by=auth.uid()))));

drop policy if exists bs_proofs_read on storage.objects;
create policy bs_proofs_read on storage.objects for select to authenticated
  using (bucket_id='bs-proofs' and (public.bs_my_role()='admin'
     or (public.bs_my_role()='sales' and exists (select 1 from public.bs_docs d
         where d.created_by=auth.uid()
           and regexp_replace(d.no,'[^A-Za-z0-9_.-]+','_','g')=split_part(name,'/',1)))));

-- Document numbers must stay unique across ALL salespeople even though each one only sees their own.
-- This returns only the highest running number per prefix (no document content).
create or replace function public.bs_max_nos() returns table(prefix text, mx int)
language sql stable security definer set search_path=public as $$
  select left(no,length(no)-3), max(right(no,3)::int) from public.bs_docs
  where public.bs_my_role() in ('sales','admin') and right(no,3) ~ '^[0-9]{3}$'
  group by 1 $$;
revoke all on function public.bs_max_nos() from public;
grant execute on function public.bs_max_nos() to authenticated;
