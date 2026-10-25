-- Hosted Supabase only, after Edge Functions are deployed. Not part of local stub tests.
-- Enable pg_cron and pg_net, then create these Vault secrets using the dashboard:
-- bmc_project_url = your https://<project-ref>.supabase.co URL
-- bmc_reconcile_token = same long random token as Edge Secret RECONCILE_TOKEN
do $check$
begin
  if to_regnamespace('cron') is null or to_regnamespace('net') is null or to_regnamespace('vault') is null then
    raise exception 'Enable Cron/pg_cron, pg_net, and Vault before scheduling';
  end if;
  if (select count(*) from vault.decrypted_secrets where name='bmc_project_url')<>1
    or (select count(*) from vault.decrypted_secrets where name='bmc_reconcile_token')<>1 then
    raise exception 'Create one bmc_project_url and one bmc_reconcile_token Vault secret first';
  end if;
  if (select decrypted_secret from vault.decrypted_secrets where name='bmc_project_url') !~ '^https://[a-z0-9-]+\.supabase\.co/?$'
    or (select length(decrypted_secret) from vault.decrypted_secrets where name='bmc_reconcile_token')<32 then
    raise exception 'Check the project URL and worker token in Vault';
  end if;
end $check$;
select cron.schedule('bmc-reconcile-payments','* * * * *',
  $job$
  select net.http_post(
    url:=rtrim((select decrypted_secret from vault.decrypted_secrets where name='bmc_project_url'),'/')||'/functions/v1/reconcile-payments',
    headers:=jsonb_build_object('Content-Type','application/json','x-reconcile-token',
      (select decrypted_secret from vault.decrypted_secrets where name='bmc_reconcile_token')),
    body:='{}'::jsonb,timeout_milliseconds:=120000);
  $job$);
