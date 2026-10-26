// Owner seed integration checks. Only run on run-local.mjs's disposable database.
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const executable = process.env.PSQL_EXE;
if (!executable || process.env.PGHOST !== '127.0.0.1' || process.env.PGDATABASE !== 'bmc_test') {
  throw new Error('Isolated local test database required');
}
function query(source) {
  return spawnSync(executable,['-X','-q','-t','-A','-v','ON_ERROR_STOP=1'],
    {input:source,encoding:'utf8',windowsHide:true});
}
function sql(source) {
  const result = query(source);
  assert.equal(result.status,0,result.stderr);
  return result.stdout.trim();
}
function rejects(source,pattern) {
  const result = query(source);
  assert.notEqual(result.status,0);
  assert.match(result.stderr,pattern);
}
const customer = 'e0000000-0000-4000-8000-000000000001';
const other = 'e0000000-0000-4000-8000-000000000002';
const admin = 'e0000000-0000-4000-8000-000000000003';
const original = readFileSync(new URL('../setup/demo-purchase.sql',import.meta.url),'utf8');
const seedFor = uid => original.replace(
  "v_customer_id uuid := '00000000-0000-0000-0000-000000000000'",
  `v_customer_id uuid := '${uid}'`);
sql(`insert into auth.users(id) values('${customer}'),('${other}'),('${admin}');
  update public.user_roles set role='admin' where user_id='${admin}';`);
const stock = () => sql('select jsonb_agg(to_jsonb(v) order by id) from public.product_variants v');
const beforeStock = stock();
const beforeOrders = Number(sql('select count(*) from public.orders'));
rejects(original,/Replace v_customer_id/);
rejects(seedFor('e0000000-0000-4000-8000-000000000099'),/Customer profile not found/);
// A mixed/missing schema must produce a useful error and roll back the temporary rename.
rejects(`begin; alter table public.orders rename to temporarily_missing_orders;
  ${seedFor(customer).replace(/^begin;$/m,'').replace(/^commit;$/m,'')}`,
  /Ecommerce setup is incomplete/);
assert.equal(Number(sql('select count(*) from public.orders')),beforeOrders);
sql(seedFor(customer));
const order = sql(`select id from public.orders where user_id='${customer}'
  and request_fingerprint='DEMO_ONLY_NO_CHARGE_V1'`);
assert.match(order,/^[0-9a-f-]{36}$/);
assert.equal(sql(`select payment_status || ':' || fulfillment_status || ':' || total_minor
  from public.orders where id='${order}'`),'paid:preparing:315000');
assert.equal(sql(`select count(*) || ':' || sum(line_total_minor)
  from public.order_items where order_id='${order}'`),'2:300000');
assert.equal(sql(`select state || ':' || provider_status || ':' || (payment_url is null)::text
  || ':' || (provider_id is null)::text from public.payments where order_id='${order}'`),
  'paid:DEMO_ONLY_NOT_XENDIT:true:true');
const asUser = (uid,source) => `set role authenticated; set request.jwt.claim.sub='${uid}'; ${source}`;
const visibleCounts = `select (select count(*) from public.orders where id='${order}') || ':' ||
  (select count(*) from public.order_items where order_id='${order}') || ':' ||
  (select count(*) from public.order_payment_summary where order_id='${order}');`;
assert.equal(sql(asUser(customer,visibleCounts)),'1:2:1');
assert.equal(sql(asUser(other,visibleCounts)),'0:0:0');
assert.equal(sql(asUser(customer,`select state from public.order_payment_summary where order_id='${order}'`)),'paid');
rejects(asUser(customer,`select public.admin_update_fulfillment('${order}','shipped')`),/Admin required/);
rejects(asUser(admin,`select public.admin_update_fulfillment('${order}','delivered')`),/Invalid fulfillment transition/);
sql(asUser(admin,`select public.admin_update_fulfillment('${order}','shipped');
  select public.admin_update_fulfillment('${order}','shipped');`));
sql(seedFor(customer));
assert.equal(sql(asUser(customer,`select fulfillment_status from public.orders where id='${order}'`)),'shipped');
sql(asUser(admin,`select public.admin_update_fulfillment('${order}','delivered')`));
sql(seedFor(customer));
assert.equal(sql(asUser(customer,`select fulfillment_status from public.orders where id='${order}'`)),'delivered');
rejects(asUser(admin,`select public.admin_update_fulfillment('${order}','preparing')`),/Invalid fulfillment transition/);
assert.equal(Number(sql('select count(*) from public.orders')),beforeOrders + 1);
assert.equal(sql(`select count(*) from public.payments where order_id='${order}'`),'1');
assert.equal(sql(`select count(*) from public.order_items where order_id='${order}'`),'2');
assert.equal(sql(`select count(*) from public.inventory_reservations where order_id='${order}'`),'0');
assert.equal(stock(),beforeStock);
assert.equal(sql(`select public.ecom_reconcile_candidates()::text like '%DEMO-NO-CHARGE-%'`),'f');
console.log('PASS: dummy purchase seed, guardrails, repeat safety, stock preservation, customer isolation, and admin/customer delivery status flow.');
