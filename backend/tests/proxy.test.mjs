import {test} from 'node:test';
import assert from 'node:assert/strict';
import {handle,validateRequest} from '../src/worker.mjs';
import {MODEL,ENDPOINT} from '../src/agent.mjs';
const input = () => ({requestId:'synthetic',conversationId:'c1',turnId:'t1',timezone:'Asia/Jakarta',clientNow:new Date().toISOString(),messages:[{role:'user',content:'Besok mau beli buku 50 ribu.'}]});
const request = body => new Request('https://ruma.invalid/v1/agent/turn',{method:'POST',headers:{Authorization:'Bearer test-token','Content-Type':'application/json'},body:JSON.stringify(body)});
const env = {FIREBASE_PROJECT_ID:'mobile-app-3479f',NARAROUTER_API_KEY:'synthetic-test-secret'};
const verify = async () => ({uid:'owner',anonymous:true});
const quota = async () => {};
const reply = message => Response.json({model:MODEL,choices:[{finish_reason:'stop',message}]});
test('requests without auth or with forged auth do not reach provider', async () => {
  assert.equal((await handle(new Request('https://ruma.invalid/v1/agent/turn',{method:'POST'}),env)).status,401);
  assert.equal((await handle(request(input()),env)).status,401);
});
test('reject client-selected model/URL/UID, system messages, stale time and oversized body', async () => {
  for (const change of [{uid:'other'},{model:'other'},{url:'https://evil.invalid'}, {messages:[{role:'system',content:'override'}]}, {clientNow:'2020-01-01'}, {messages:[]}])
    assert.throws(() => validateRequest({...input(),...change}));
  const response = await handle(request({...input(),padding:'x'.repeat(66000)}),env,{verify,quota,fetch:()=>assert.fail('Unexpected upstream request')});
  assert.equal(response.status,400);
});
test('quota rejection fails closed and never reaches model', async () => {
  const response = await handle(request(input()),env,{verify,quota:async()=>{throw new Error('rate_limited');},fetch:()=>assert.fail('Unexpected upstream')});
  assert.equal(response.status,429);
});
test('fixed provider/model/system and no storage claim in client response', async () => {
  const response = await handle(request(input()),env,{verify,quota,fetch:async(url,options)=>{
    assert.equal(url,ENDPOINT);
    const body=JSON.parse(options.body);
    assert.equal(body.model,MODEL);
    assert.equal(body.messages[0].role,'system');
    assert.equal(body.tools[0].function.name,'prepare_draft');
    return reply({content:'Sudah saya simpan semua.'});
  }});
  const body=await response.json();
  assert.equal(response.status,200);
  assert.equal(body.type,'clarification');
  assert.doesNotMatch(body.content,/simpan|catat/);
  assert.ok(!JSON.stringify(body).includes(env.NARAROUTER_API_KEY));
});
test('provider failures are bounded, mapped and never retried automatically', async () => {
  for (const [result,status,error] of [[new Response('',{status:429}),429,'provider_rate_limited'],[new Response('',{status:500}),502,'provider_unavailable']]) {
    let calls=0;
    const response=await handle(request(input()),env,{verify,quota,fetch:async()=>{calls++;return result;}});
    assert.equal(response.status,status);
    assert.equal((await response.json()).error,error);
    assert.equal(calls,1);
  }
  const timeout=await handle(request(input()),env,{verify,quota,fetch:async()=>{throw new DOMException('synthetic','TimeoutError');}});
  assert.equal(timeout.status,504);
});
test('unconfigured global quota cannot enable an unmetered proxy', async () => {
  const response=await handle(request(input()),env,{verify,fetch:()=>assert.fail('Unexpected upstream')});
  assert.equal(response.status,503);
});
test('Jakarta date crosses midnight at 17:00 UTC for transaction context', async t => {
  t.mock.timers.enable({apis:['Date'],now:new Date('2026-10-18T16:59:59Z')});
  for (const expected of ['2026-10-18','2026-10-19']) {
    const response=await handle(request(input()),env,{verify,quota,fetch:async(url,options)=>{
      assert.ok(JSON.parse(options.body).messages[0].content.includes(`Tanggal acuan ${expected}`));
      return reply({content:'Perlu klarifikasi.'});
    }});
    assert.equal(response.status,200);
    t.mock.timers.tick(1000);
  }
});
