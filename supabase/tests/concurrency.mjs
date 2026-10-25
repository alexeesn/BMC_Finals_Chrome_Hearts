// Run only against the disposable loopback database initialized by run-local.ps1.
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
const results = await Promise.all([checkout(1),checkout(2)]);
assert.equal(results.filter(result => result.code === 0).length,1);
assert.match(results.find(result => result.code !== 0).error,/Not enough stock/);
assert.equal(sql("select stock_on_hand||':'||stock_reserved from public.product_variants where id='30000000-0000-4000-8000-000000000007'"),'1:1');
assert.equal(sql('select count(*) from public.orders'),'1');
console.log('PASS: concurrent last-item checkout reserves exactly once.');
