-- Document status steps (To issue / To send / To collect / Paid / Sent). Safe to run more than once.
-- Lets Sales mark their OWN approved documents as "sent" (needed for the WhatsApp button). Touches only bs_ objects.
create or replace function public.bs_docs_guard() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  new.created_by := old.created_by;
  new.no := old.no;
  if coalesce(current_setting('bs.skip_guard',true),'') <> '1' and public.bs_my_role() <> 'admin' then
    new.approved_by := old.approved_by;
    if new.status = 'approved' then raise exception 'Only Admin can approve'; end if;
  end if;
  new.updated_at := now();
  return new;
end $$;

create or replace function public.bs_mark_sent(p_no text) returns void
language plpgsql security definer set search_path=public as $$
begin
  perform set_config('bs.skip_guard','1',true);
  update public.bs_docs
     set data = coalesce(data,'{}'::jsonb) || jsonb_build_object('sent',true,'sentAt',now()::text)
   where no = p_no and status = 'approved'
     and (created_by = auth.uid() or public.bs_my_role() = 'admin');
end $$;
revoke all on function public.bs_mark_sent(text) from public;
grant execute on function public.bs_mark_sent(text) to authenticated;
