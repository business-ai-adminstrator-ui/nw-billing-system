-- Give people a role AFTER you create them in Supabase → Authentication → Users
-- (tick "Auto Confirm User"). Edit the emails/names, then run in SQL Editor.
insert into public.bs_profiles(id,role,name)
select id,'admin','NW Admin' from auth.users where email='admin@yourcompany.com'
on conflict (id) do update set role=excluded.role,name=excluded.name;

insert into public.bs_profiles(id,role,name)
select id,'sales','Apple Sim' from auth.users where email='sales1@yourcompany.com'
on conflict (id) do update set role=excluded.role,name=excluded.name;
