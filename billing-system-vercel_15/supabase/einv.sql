-- E-Invoice Info (Admin only). Safe to run more than once. Does not touch any other table.
create table if not exists public.bs_einv(
  code text primary key,
  currency text default 'MYR',
  name text not null,
  tax_registered boolean default false,
  debtor_type text default '',
  reg_no text default '',
  tin text default '',
  email text default '',
  mobile text default '',
  phone text default '',
  area text default '',
  agent text default '',
  active boolean default true,
  updated_at timestamptz default now()
);
alter table public.bs_einv enable row level security;
drop policy if exists einv_admin on public.bs_einv;
create policy einv_admin on public.bs_einv for all to authenticated
  using (public.bs_my_role()='admin') with check (public.bs_my_role()='admin');
