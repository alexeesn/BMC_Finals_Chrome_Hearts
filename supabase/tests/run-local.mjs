// Disposable loopback PostgreSQL tests; does not connect to an existing service or hosted account.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import {spawn,execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {fileURLToPath} from 'node:url';
const execute = promisify(execFile);
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const bin = process.argv[2] || process.env.POSTGRES_BIN || 'C:\\Program Files\\PostgreSQL\\18\\bin';
const executable = name => path.join(bin,name + (process.platform === 'win32' ? '.exe' : ''));
const folder = fs.mkdtempSync(path.join(os.tmpdir(),'bmc-ecom-test-'));
const data = path.join(folder,'data');
const delay = ms => new Promise(resolve => setTimeout(resolve,ms));
const listener = net.createServer();
await new Promise((resolve,reject) => { listener.once('error',reject); listener.listen(0,'127.0.0.1',resolve); });
const port = listener.address().port;
await new Promise(resolve => listener.close(resolve));
const env = {...process.env,PGHOST:'127.0.0.1',PGPORT:String(port),PGUSER:'postgres',PGDATABASE:'bmc_test',PGPASSWORD:'',PSQL_EXE:executable('psql')};
let server; let logDescriptor;
async function run(file,args,overrides = {}) {
  const result = await execute(file,args,{cwd:root,env,windowsHide:true,timeout:120000,maxBuffer:2*1024*1024,...overrides});
  if (result.stdout.trim()) console.log(result.stdout.trim());
  return result;
}
try {
  const initialized = await execute(executable('initdb'),['-D',data,'-U','postgres','-A','trust','--no-locale','--encoding=UTF8'],{windowsHide:true,timeout:120000});
  fs.writeFileSync(path.join(folder,'init.log'),initialized.stdout + initialized.stderr);
  logDescriptor = fs.openSync(path.join(folder,'server.log'),'a');
  server = spawn(executable('postgres'),['-D',data,'-h','127.0.0.1','-p',String(port)],{windowsHide:true,stdio:['ignore',logDescriptor,logDescriptor]});
  let startupError;
  server.on('error',error => { startupError = error; });
  let ready = false;
  for (let attempt=0; attempt<50; attempt++) {
    if (startupError) throw startupError;
    try { await execute(executable('pg_isready'),['-q'],{env,windowsHide:true,timeout:3000}); ready=true; break; } catch { await delay(100); }
  }
  if (!ready) throw new Error('Local server did not start; inspect server.log');
  await run(executable('psql'),['-X','-q','-d','postgres','-v','ON_ERROR_STOP=1','-c','create database bmc_test']);
  const migrations = fs.readdirSync(path.join(root,'supabase','migrations'))
    .filter(file => /^\d+_.*\.sql$/.test(file)).sort().map(file => 'migrations/' + file);
  for (const file of ['tests/bootstrap.sql',...migrations,'seed.sql','tests/database.sql']) {
    await run(executable('psql'),['-X','-q','-v','ON_ERROR_STOP=1','-o',path.join(folder,'queries.log'),'-f',path.join(root,'supabase',file)]);
  }
  await run(process.execPath,['supabase/tests/concurrency.mjs']);
  await run(process.execPath,['supabase/tests/demo-purchase.mjs']);
  await run(process.execPath,['--test','supabase/tests/edge.test.mjs']);
  console.log('PASS: fresh migrations, database permissions/state checks, concurrent checkout, dummy purchase/status flow, and mocked Edge handler tests.');
} catch (error) {
  console.error(error.stderr || error.message); process.exitCode=1;
} finally {
  if (server && server.exitCode === null) {
    try { await execute(executable('pg_ctl'),['-D',data,'-m','fast','-w','stop'],{windowsHide:true,timeout:15000}); }
    catch { server.kill(); }
  }
  if (logDescriptor !== undefined) fs.closeSync(logDescriptor);
  console.log('Test logs retained at: ' + folder);
}
