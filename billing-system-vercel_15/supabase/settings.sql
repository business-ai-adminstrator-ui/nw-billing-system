-- Price settings (Business AI standard price). Safe to run more than once. Touches only bs_ objects.
create table if not exists public.bs_settings(key text primary key, value jsonb not null, updated_at timestamptz default now());
alter table public.bs_settings enable row level security;
drop policy if exists set_read on public.bs_settings;
create policy set_read on public.bs_settings for select to authenticated using (public.bs_my_role() in ('sales','admin'));
drop policy if exists set_write on public.bs_settings;
create policy set_write on public.bs_settings for all to authenticated using (public.bs_my_role()='admin') with check (public.bs_my_role()='admin');
insert into public.bs_settings(key,value) values('bsai_price','{"one":3940,"many":3540}') on conflict (key) do nothing;
