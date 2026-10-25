-- Owner-run in SQL Editor after the intended account exists in Authentication > Users.
-- Replace the zero UUID with THAT account's Auth user UUID. Never use client signup metadata for roles.
do $$
declare intended_admin uuid := '00000000-0000-0000-0000-000000000000';
begin
  if intended_admin='00000000-0000-0000-0000-000000000000' then raise exception 'Replace intended_admin with the actual Auth user UUID first'; end if;
  if not exists(select 1 from auth.users where id=intended_admin) then raise exception 'Auth user not found'; end if;
  insert into public.user_roles(user_id,role) values(intended_admin,'admin') on conflict(user_id) do update set role='admin';
end $$;
