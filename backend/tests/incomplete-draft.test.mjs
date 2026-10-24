import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {handle} from '../src/worker.mjs';
import {MODEL} from '../src/agent.mjs';
const fixture=JSON.parse(await readFile(new URL('../../docs/qa/final-stages-1-3/provider-fixture.json',import.meta.url),'utf8'));
const text='Besok baca jurnal. Tadi makan 18 ribu.';
async function turn(content,upstream) {
 let calls=0;
 const request=new Request('https://ruma.invalid/v1/agent/turn',{method:'POST',headers:{Authorization:'Bearer synthetic','Content-Type':'application/json'},body:JSON.stringify({requestId:'replay',conversationId:'replay',turnId:'replay',clientNow:new Date().toISOString(),timezone:'Asia/Jakarta',messages:[{role:'user',content}]})});
 const response=await handle(request,{FIREBASE_PROJECT_ID:'demo-ruma',NARAROUTER_API_KEY:'synthetic'},{verify:async()=>({uid:'synthetic',anonymous:true}),quota:async()=>{},fetch:async()=>{calls++;return upstream();}});
 assert.equal(calls,1,'never retry provider');return {status:response.status,body:await response.json()};
}
test('captured real partial output cannot silently discard the agenda sentence',async()=>{
 const r=await turn(text,()=>Response.json(fixture));assert.equal(r.status,200);assert.equal(r.body.type,'clarification');assert.equal(r.body.reason,'incomplete_draft');assert.deepEqual(r.body.items,[]);
});
test('unverified provider payload asks for clarification, never exposes saved claims or retries',async()=>{
 for(const data of ['not json',JSON.stringify({model:'wrong-model',choices:[]})]){
  const r=await turn(text,()=>new Response(data));assert.equal(r.status,200);assert.equal(r.body.reason,'incomplete_draft');assert.deepEqual(r.body.items,[]);assert.doesNotMatch(r.body.content,/sudah|tersimpan/);
 }
});
test('fully covered statements, greetings and rupiah punctuation retain combined draft',async()=>{
 const full=structuredClone(fixture),msg=full.choices[0].message,args=JSON.parse(msg.tool_calls[0].function.arguments);
 args.items.unshift({action:'create_agenda',title:'Baca jurnal',localDate:'2026-10-22',deadlineLocal:null,startLocal:null,durationMinutes:30,amountRupiah:null,transactionType:null,categoryId:null,transactionStatus:null,sourceQuote:'Besok baca jurnal'});
 msg.tool_calls[0].function.arguments=JSON.stringify(args);full.model=MODEL;
 const r=await turn('Halo. '+text,()=>Response.json(full));assert.equal(r.status,200);assert.equal(r.body.type,'draft_proposal');assert.equal(r.body.items.length,2);
 const money=structuredClone(fixture);const a=JSON.parse(money.choices[0].message.tool_calls[0].function.arguments);a.items[0].sourceQuote='Tadi makan Rp18.000';money.choices[0].message.tool_calls[0].function.arguments=JSON.stringify(a);
 assert.equal((await turn('Tadi makan Rp18.000.',()=>Response.json(money))).body.type,'draft_proposal');
});
