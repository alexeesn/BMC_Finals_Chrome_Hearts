// Run only against the disposable loopback database initialized by run-local.mjs.
import { spawnSync,spawn } from 'node:child_process';
import assert from 'node:assert/strict';
const executable = process.env.PSQL_EXE;
if (!executable || process.env.PGHOST !== '127.0.0.1' || process.env.PGDATABASE !== 'bmc_test') throw new Error('Isolated local test database required');
function sql(text) {
  const result = spawnSync(executable,['-X','-q','-t','-A','-v','ON_ERROR_STOP=1'],{input:text,encoding:'utf8',windowsHide:true});
  if (result.status !== 0) throw new Error(result.stderr);
  return result.stdout.trim();
}
sql(`insert into auth.users(id) values('f0000000-0000-4000-8000-000000000001'),('f0000000-0000-4000-8000-000000000002');
insert into public.addresses(id,user_id,recipient,phone,province,city,barangay,street,postal_code) values
('f1000000-0000-4000-8000-000000000001','f0000000-0000-4000-8000-000000000001','One','09123456789','Metro Manila','QC','Sample','Sample Street','1100'),
('f1000000-0000-4000-8000-000000000002','f0000000-0000-4000-8000-000000000002','Two','09123456789','Metro Manila','QC','Sample','Sample Street','1100');
update public.product_variants set stock_on_hand=1 where id='30000000-0000-4000-8000-000000000007';`);
async function checkout(number) {
  return new Promise(resolve => {
    const child = spawn(executable,['-X','-q','-t','-A','-v','ON_ERROR_STOP=1'],{windowsHide:true}); let error = '';
    child.stdout.resume(); child.stderr.on('data',data => { error += data; });
    child.on('close',code => resolve({code,error}));
    child.stdin.end(`begin; select public.ecom_create_checkout('f0000000-0000-4000-8000-00000000000${number}','f1000000-0000-4000-8000-00000000000${number}',
    '[{"variant_id":"30000000-0000-4000-8000-000000000007","quantity":1}]','buy_now','f2000000-0000-4000-8000-00000000000${number}'); select pg_sleep(0.3); commit;`);
  });
}
const beforeReservation = sql("select updated_at from public.product_variants where id='30000000-0000-4000-8000-000000000007'");
const results = await Promise.all([checkout(1),checkout(2)]);
assert.equal(results.filter(result => result.code === 0).length,1);
assert.match(results.find(result => result.code !== 0).error,/Not enough stock/);
assert.equal(sql("select stock_on_hand||':'||stock_reserved from public.product_variants where id='30000000-0000-4000-8000-000000000007'"),'1:1');
assert.equal(sql('select count(*) from public.orders'),'1');
console.log('PASS: concurrent last-item checkout reserves exactly once.');

sql("insert into auth.users(id) values('f0000000-0000-4000-8000-000000000003'); update public.user_roles set role='admin' where user_id='f0000000-0000-4000-8000-000000000003'");
function saveVariant(expected, stock) {
  return `set role authenticated; set request.jwt.claim.sub='f0000000-0000-4000-8000-000000000003';
  select public.admin_save_variant_checked('30000000-0000-4000-8000-000000000007','20000000-0000-4000-8000-000000000003',
    'DEMO-CAP','One size',850000,${stock},true,'${expected}'::timestamptz);`;
}
function expectRejected(text, pattern) {
  const result = spawnSync(executable,['-X','-q','-t','-A','-v','ON_ERROR_STOP=1'],{input:text,encoding:'utf8',windowsHide:true});
  assert.notEqual(result.status,0); assert.match(result.stderr,pattern);
}
expectRejected(saveVariant(beforeReservation,99),/Variant changed/);
assert.equal(sql("select stock_on_hand||':'||stock_reserved from public.product_variants where id='30000000-0000-4000-8000-000000000007'"),'1:1');
const current = sql("select updated_at from public.product_variants where id='30000000-0000-4000-8000-000000000007'");
expectRejected(saveVariant(current,0),/check constraint/);
sql(saveVariant(current,1));
const beforePaid = sql("select updated_at from public.product_variants where id='30000000-0000-4000-8000-000000000007'");
sql(`select public.ecom_apply_session(jsonb_build_object('id','ps-concurrentadminfixtureaa','reference_id',reference_id,
  'business_id','test-business','session_type','PAY','mode','PAYMENT_LINK','capture_method','AUTOMATIC',
  'country','PH','currency','PHP','amount_minor',expected_amount_minor,'expires_at',expires_at,
  'status','COMPLETED','payment_succeeded',true,'payment_id','py-concurrentadminfixtureaa')) from public.payments limit 1;`);
expectRejected(saveVariant(beforePaid,1),/Variant changed/);
assert.equal(sql("select stock_on_hand||':'||stock_reserved from public.product_variants where id='30000000-0000-4000-8000-000000000007'"),'0:0');
console.log('PASS: stale admin forms cannot overwrite reservation/payment stock changes or reserved floors.');
