-- Open access (no login). Run once in Supabase -> SQL Editor.
-- WARNING: after this, anyone who knows the website address can read and change the billing data.
alter table public.bs_docs     alter column created_by drop not null;
alter table public.bs_payments alter column created_by drop not null;

do $$ declare t text; begin
  foreach t in array array['bs_docs','bs_payments','bs_notifs','bs_einv','bs_settings'] loop
    execute format('drop policy if exists open_all on public.%I', t);
    execute format('create policy open_all on public.%I for all to anon using (true) with check (true)', t);
  end loop;
end $$;

drop policy if exists bs_proofs_open_read on storage.objects;
create policy bs_proofs_open_read on storage.objects for select to anon using (bucket_id='bs-proofs');
drop policy if exists bs_proofs_open_write on storage.objects;
create policy bs_proofs_open_write on storage.objects for insert to anon with check (bucket_id='bs-proofs');

create or replace function public.bs_max_nos() returns table(prefix text, mx int)
language sql stable security definer set search_path=public as $$
  select left(no,length(no)-3), max(right(no,3)::int) from public.bs_docs
  where right(no,3) ~ '^[0-9]{3}$' group by 1 $$;
grant execute on function public.bs_max_nos() to anon, authenticated;
