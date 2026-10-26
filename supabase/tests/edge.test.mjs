import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Backend, minorAmount, hostedUrl, equalToken, handleCreate, handleWebhook, handleReconcile, handleReturn, verifiedSession } from '../functions/_shared/backend.ts';

const user = 'a0000000-0000-4000-8000-000000000001';
const oid = 'e0000000-0000-4000-8000-000000000001';
const sid = 'ps-aaaaaaaaaaaaaaaaaaaaaaaa';
const pid = 'py-aaaaaaaaaaaaaaaaaaaaaaaa';
const prid = 'pr-aaaaaaaaaaaaaaaaaaaaaaaa';
const env = { SUPABASE_URL:'https://example.supabase.co', SUPABASE_ANON_KEY:'public-test-value', SUPABASE_SECRET_KEYS:'{"default":"sb_secret_fixture"}', XENDIT_SECRET_KEY:'xnd_development_fixture', XENDIT_WEBHOOK_TOKEN:'fixture-webhook-token', RECONCILE_TOKEN:'fixture-worker-token' };
const session = { payment_session_id:sid, reference_id:'bmc_' + oid, business_id:'fixture-business', session_type:'PAY',mode:'PAYMENT_LINK',capture_method:'AUTOMATIC',currency:'PHP',country:'PH',amount:24150,status:'ACTIVE',expires_at:'2030-01-01T00:30:00Z',payment_link_url:'https://dev.xen.to/fixture' };
const owned = { order:{id:oid,order_number:'BMC-FIXTURE',payment_status:'pending',total_minor:2415000,currency:'PHP',expires_at:'2030-01-01T00:30:00Z'},payment:{reference_id:session.reference_id,expected_amount_minor:2415000,state:'creating',claim_token:oid,expires_at:session.expires_at},items:[] };
const body = {source:'buy_now',address_id:oid,idempotency_key:oid,items:[{variant_id:oid,quantity:2,price_minor:1}],user_id:'forged-user'};
const response = data => new Response(JSON.stringify(data),{status:200,headers:{'content-type':'application/json'}});
const request = (data = body,headers = {}) => new Request('https://example.supabase.co/functions/v1/create-payment',{method:'POST',headers:{authorization:'Bearer header.payload.signature','content-type':'application/json',...headers},body:JSON.stringify(data)});
function bindings(handler, overrides = {}) { return {env:name => ({...env,...overrides})[name],fetch:async (url,options = {}) => handler(String(url),options)}; }

test('exact centavo conversion rejects excess precision and unsafe values', () => {
  assert.equal(minorAmount(150.25),15025); assert.equal(minorAmount('24150'),2415000);
  assert.throws(() => minorAmount('1.001')); assert.throws(() => minorAmount('-10')); assert.throws(() => minorAmount('1e3'));
});
test('only hosted test domains are allowed', () => {
  assert.equal(hostedUrl('https://dev.xen.to/test'),'https://dev.xen.to/test');
  for (const url of ['https://xen.to/live','https://dev.xen.to.evil.test/x','https://user@dev.xen.to/x','http://dev.xen.to/x']) assert.throws(() => hostedUrl(url));
});
test('live secret keys are refused before provider calls', () => {
  const backend = new Backend(bindings(() => assert.fail('No network expected'),{XENDIT_SECRET_KEY:'xnd_production_fixture'}));
  assert.throws(() => backend.testKey(),/Test Mode/);
});
test('webhook token comparison rejects missing/mismatched values', async () => {
  assert.equal(await equalToken('abc','abc'),true); assert.equal(await equalToken('abc','abd'),false); assert.equal(await equalToken('',''),false);
});
test('checkout requires a user JWT rather than a public API key', async () => {
  const result = await handleCreate(request(body,{authorization:'Bearer sb_publishable_fixture'}),bindings(() => assert.fail('No network expected')));
  assert.equal(result.status,401);
});
test('checkout validates quantity before creating an order', async () => {
  const result = await handleCreate(request({...body,items:[{variant_id:oid,quantity:0}]}),bindings(url => { assert.ok(url.endsWith('/auth/v1/user')); return response({id:user}); }));
  assert.equal(result.status,400);
});
test('checkout uses authenticated identity and backend totals, not posted prices', async () => {
  let providerCalls = 0;
  const result = await handleCreate(request(),bindings((url,options) => {
    const data = options.body ? JSON.parse(options.body) : null;
    if (url.endsWith('/auth/v1/user')) return response({id:user});
    if (url.endsWith('/ecom_create_checkout')) {
      assert.equal(data.p_user,user); assert.deepEqual(data.p_items,[{variant_id:oid,quantity:2}]);
      assert.equal(options.headers.apikey,'sb_secret_fixture'); assert.equal(options.headers.authorization,undefined);
      return response(owned);
    }
    if (url.endsWith('/ecom_claim_creation')) return response({claimed:true,data:owned});
    if (url === 'https://api.xendit.co/sessions') {
      providerCalls++; assert.equal(data.amount,24150); assert.equal(data.capture_method,'AUTOMATIC'); assert.equal(data.allow_save_payment_method,'DISABLED');
      assert.match(data.success_return_url,/payment-return\?result=success$/); return response(session);
    }
    if (url.endsWith('/ecom_apply_session')) { assert.equal(data.p_session.amount_minor,2415000); return response({data:{...owned,payment:{...owned.payment,state:'active',payment_url:session.payment_link_url}}}); }
    assert.fail('Unexpected request: ' + url);
  }));
  assert.equal(result.status,200); assert.equal(providerCalls,1);
  const safe = await result.json(); assert.equal(safe.total_minor,2415000); assert.equal(safe.claim_token,undefined); assert.equal(safe.delivery_address,undefined);
});
test('concurrent/retried creation cannot create a second provider session', async () => {
  const result = await handleCreate(request(),bindings(url => {
    if (url.endsWith('/auth/v1/user')) return response({id:user});
    if (url.endsWith('/ecom_create_checkout')) return response(owned);
    if (url.endsWith('/ecom_claim_creation')) return response({claimed:false,data:owned});
    assert.fail('Provider must not be called');
  }));
  assert.equal(result.status,409);
});
test('network timeout keeps an unknown outcome instead of releasing stock', async () => {
  let recorded = false;
  const result = await handleCreate(request(),bindings((url,options) => {
    if (url.endsWith('/auth/v1/user')) return response({id:user});
    if (url.endsWith('/ecom_create_checkout')) return response(owned);
    if (url.endsWith('/ecom_claim_creation')) return response({claimed:true,data:owned});
    if (url === 'https://api.xendit.co/sessions') throw new Error('timeout with sensitive internal detail');
    if (url.endsWith('/ecom_creation_failed')) { assert.equal(JSON.parse(options.body).p_definitive,false); recorded = true; return response(null); }
    assert.fail(url);
  }));
  assert.equal(result.status,503); assert.ok(recorded); assert.doesNotMatch(await result.text(),/sensitive internal detail/);
});
test('forged webhook token cannot reach database or provider', async () => {
  const result = await handleWebhook(request({event:'payment_session.completed',data:{payment_session_id:sid}}),bindings(() => assert.fail('No request expected')));
  assert.equal(result.status,401);
});
for (const event of ['payment_session.completed','payment_session.expired']) {
  test('authenticated dashboard SAVE fixture is acknowledged without writes: ' + event, async () => {
    const fixture = {event,data:{id:sid,reference_id:'test_session',session_type:'SAVE',country:'ID',currency:'IDR',amount:100000,status:event.endsWith('expired') ? 'EXPIRED' : 'COMPLETED'}};
    const result = await handleWebhook(request(fixture,{'x-callback-token':env.XENDIT_WEBHOOK_TOKEN}),bindings(() => assert.fail('Dashboard fixture must not reach database/provider')));
    assert.equal(result.status,200);
    assert.deepEqual(await result.json(),{received:true,ignored:true,reason:'UNSUPPORTED_SESSION_TYPE'});
  });
}
test('dashboard fixture still requires the real webhook verification token', async () => {
  const result = await handleWebhook(request({event:'payment_session.expired',data:{id:sid,reference_id:'test_session',session_type:'SAVE'}},{'x-callback-token':'wrong-token'}),bindings(() => assert.fail('No network expected')));
  assert.equal(result.status,401);
});
test('unrelated merchant references are acknowledged without touching orders', async () => {
  const result = await handleWebhook(request({event:'payment_session.completed',data:{id:sid,reference_id:'test_session',session_type:'PAY'}},{'x-callback-token':env.XENDIT_WEBHOOK_TOKEN}),bindings(() => assert.fail('Unrelated event must not touch orders')));
  assert.equal(result.status,200); assert.equal((await result.json()).reason,'UNRELATED_REFERENCE');
});
test('shop PAY callbacks accept data.id and retain provider verification', async () => {
  let applied;
  const result = await handleWebhook(request({event:'payment_session.completed',data:{id:sid,reference_id:session.reference_id,session_type:'PAY',status:'COMPLETED'}},{'x-callback-token':env.XENDIT_WEBHOOK_TOKEN}),bindings((url,options) => {
    if (url.endsWith('/ecom_record_event')) return response({id:oid,state:'pending'});
    if (url.endsWith('/sessions/' + sid)) return response({...session,id:sid,payment_session_id:undefined});
    if (url.endsWith('/ecom_apply_session')) { applied=JSON.parse(options.body).p_session; return response({}); }
    if (url.endsWith('/ecom_finish_event')) return response(null);
    assert.fail(url);
  }));
  assert.equal(result.status,200); assert.equal(applied.id,sid); assert.equal(applied.status,'ACTIVE'); assert.equal(applied.payment_succeeded,false);
});
test('conflicting canonical and legacy IDs cannot select a payment resource', async () => {
  const result = await handleWebhook(request({event:'payment_session.completed',data:{id:sid,payment_session_id:'ps-bbbbbbbbbbbbbbbbbbbbbbbb',reference_id:session.reference_id,session_type:'PAY'}},{'x-callback-token':env.XENDIT_WEBHOOK_TOKEN}),bindings(() => assert.fail('No network expected')));
  assert.equal(result.status,400); assert.match((await result.json()).error,/Conflicting/);
});
test('missing IDs on shop PAY callbacks are rejected rather than acknowledged', async () => {
  const result = await handleWebhook(request({event:'payment_session.completed',data:{reference_id:session.reference_id,session_type:'PAY'}},{'x-callback-token':env.XENDIT_WEBHOOK_TOKEN}),bindings(() => assert.fail('No network expected')));
  assert.equal(result.status,400); assert.match((await result.json()).error,/Invalid provider resource ID/);
});
test('webhook ignores claimed paid status and looks up the actual provider session', async () => {
  let applied;
  const result = await handleWebhook(request({event:'payment_session.completed',data:{payment_session_id:sid,status:'COMPLETED',amount:1}},{'x-callback-token':env.XENDIT_WEBHOOK_TOKEN}),bindings((url,options) => {
    if (url.endsWith('/ecom_record_event')) return response({id:oid,state:'pending'});
    if (url === 'https://api.xendit.co/sessions/' + sid) return response(session);
    if (url.endsWith('/ecom_apply_session')) { applied = JSON.parse(options.body).p_session; return response({}); }
    if (url.endsWith('/ecom_finish_event')) return response(null);
    assert.fail(url);
  }));
  assert.equal(result.status,200); assert.equal(applied.status,'ACTIVE'); assert.equal(applied.amount_minor,2415000); assert.equal(applied.payment_succeeded,false);
});
test('processed webhook duplicate is acknowledged without another effect', async () => {
  const result = await handleWebhook(request({event:'payment_session.completed',data:{payment_session_id:sid}},{'x-callback-token':env.XENDIT_WEBHOOK_TOKEN}),bindings(url => {
    assert.ok(url.endsWith('/ecom_record_event')); return response({state:'processed'});
  }));
  assert.equal(result.status,200); assert.equal((await result.json()).duplicate,true);
});
test('paid evidence must be captured, correlated, and match exact amount/currency', async () => {
  const backend = new Backend(bindings(url => {
    if (url.endsWith('/sessions/' + sid)) return response({...session,status:'COMPLETED',payment_id:pid,payment_request_id:prid});
    if (url.endsWith('/v3/payments/' + pid)) return response({payment_id:pid,payment_request_id:prid,business_id:session.business_id,reference_id:session.reference_id,currency:'PHP',type:'PAY',capture_method:'AUTOMATIC',request_amount:24150,status:'SUCCEEDED',captures:[{capture_amount:24150}]});
    assert.fail(url);
  }));
  assert.equal((await verifiedSession(backend,sid)).payment_succeeded,true);
});
test('session completion without captured money cannot mark paid', async () => {
  const backend = new Backend(bindings(url => {
    if (url.endsWith('/sessions/' + sid)) return response({...session,status:'COMPLETED',payment_id:pid,payment_request_id:prid});
    return response({payment_id:pid,payment_request_id:prid,business_id:session.business_id,currency:'PHP',type:'PAY',capture_method:'AUTOMATIC',request_amount:24150,status:'AUTHORIZED',captures:[]});
  }));
  assert.equal((await verifiedSession(backend,sid)).payment_succeeded,false);
});
test('a different payment currency is rejected', async () => {
  const backend = new Backend(bindings(url => {
    if (url.endsWith('/sessions/' + sid)) return response({...session,status:'COMPLETED',payment_id:pid,payment_request_id:prid});
    return response({payment_id:pid,payment_request_id:prid,business_id:session.business_id,currency:'USD',type:'PAY',capture_method:'AUTOMATIC',request_amount:24150,status:'SUCCEEDED',captures:[{capture_amount:24150}]});
  }));
  await assert.rejects(verifiedSession(backend,sid),/evidence mismatch/);
});
test('partial capture is not accepted as the full order payment', async () => {
  const backend = new Backend(bindings(url => {
    if (url.endsWith('/sessions/' + sid)) return response({...session,status:'COMPLETED',payment_id:pid,payment_request_id:prid});
    return response({payment_id:pid,payment_request_id:prid,business_id:session.business_id,currency:'PHP',type:'PAY',capture_method:'AUTOMATIC',request_amount:24150,status:'SUCCEEDED',captures:[{capture_amount:100}]});
  }));
  assert.equal((await verifiedSession(backend,sid)).payment_succeeded,false);
});
test('configured browser preflight succeeds without auth, database, or provider calls', async () => {
  const origin = 'http://localhost:5173';
  const result = await handleCreate(new Request('https://example.supabase.co/functions/v1/create-payment', {
    method:'OPTIONS', headers:{origin,'access-control-request-method':'POST',
      'access-control-request-headers':'authorization,apikey,content-type,x-client-info'},
  }), bindings(() => assert.fail('Preflight must not make network calls'), {APP_ORIGINS:origin}));
  assert.equal(result.status,204);
  assert.equal(result.headers.get('access-control-allow-origin'),origin);
  for (const header of ['authorization','apikey','content-type','x-client-info']) {
    assert.ok(result.headers.get('access-control-allow-headers').split(',').map(value => value.trim()).includes(header));
  }
});
test('configured browser receives readable auth errors with CORS headers', async () => {
  const origin = 'http://localhost:5173';
  const result = await handleCreate(request(body,{origin,authorization:'Bearer sb_publishable_fixture'}),
    bindings(() => assert.fail('Invalid auth must not make network calls'),{APP_ORIGINS:origin}));
  assert.equal(result.status,401);
  assert.equal(result.headers.get('access-control-allow-origin'),origin);
  assert.equal(typeof (await result.json()).error,'string');
});
test('unconfigured browser origins cannot call checkout', async () => {
  const result = await handleCreate(request(body,{origin:'https://untrusted.example'}),bindings(() => assert.fail('No network expected')));
  assert.equal(result.status,403);
});
test('expired session with a payable asynchronous attempt retains its hold', async () => {
  const backend = new Backend(bindings(url => {
    if (url.endsWith('/sessions/' + sid)) return response({...session,status:'EXPIRED',latest_payment_request_id:prid});
    return response({payment_request_id:prid,business_id:session.business_id,currency:'PHP',request_amount:24150,status:'REQUIRES_ACTION'});
  }));
  assert.equal((await verifiedSession(backend,sid)).status,'UNCERTAIN');
});
test('worker authentication is required', async () => {
  const result = await handleReconcile(request({}),bindings(() => assert.fail('No network expected'))); assert.equal(result.status,401);
});
test('authenticated worker processes a pending inbox event and polls each session once', async () => {
  let providerCalls = 0, finished = false;
  const result = await handleReconcile(request({}, {'x-reconcile-token':env.RECONCILE_TOKEN}),bindings((url,options) => {
    if (url.endsWith('/ecom_reconcile_candidates')) return response({sessions:[sid],events:[{id:oid,provider_id:sid}],unresolved:[]});
    if (url.endsWith('/sessions/' + sid)) { providerCalls++; return response(session); }
    if (url.endsWith('/ecom_apply_session')) return response({});
    if (url.endsWith('/ecom_finish_event')) { assert.equal(JSON.parse(options.body).p_state,'processed'); finished = true; return response(null); }
    assert.fail(url);
  }));
  assert.equal(result.status,200); assert.equal(providerCalls,1); assert.ok(finished);
  assert.deepEqual(await result.json(),{processed:1,failed:0,unresolved:[]});
});
test('return page performs no database or payment writes', () => {
  assert.equal(handleReturn(new Request('https://example.test/?result=success')).status,200);
  assert.equal(handleReturn(new Request('https://example.test/',{method:'POST'})).status,405);
});
