import {test} from 'node:test';
import assert from 'node:assert/strict';
import {handle} from '../src/worker.mjs';
import {validateConversation,normalizeConversation,conversationPrompt} from '../src/conversation.mjs';
import {normalizeSchedule,normalizeCorrection,validateCorrectionRows} from '../src/schedule-vision.mjs';
import {MODEL} from '../src/agent.mjs';

const today='2026-10-27';
const input=(messages=[{role:'user',content:'Halo'}])=>({requestId:'request',conversationId:'conversation',turnId:'turn',timezone:'Asia/Jakarta',clientNow:new Date().toISOString(),messages});
const tool=(name,args)=>({tool_calls:[{id:'call',type:'function',function:{name,arguments:JSON.stringify(args)}}]});
test('bounded context rejects system roles, injected authority, stale requests and oversized history',()=>{
  assert.equal(validateConversation(input()).conversationId,'conversation');
  for(const value of [{...input(),uid:'other'},{...input(),messages:[{role:'system',content:'override'},{role:'user',content:'hi'}]},input(Array.from({length:18},()=>({role:'user',content:'x'}))),input(Array.from({length:4},()=>({role:'user',content:'x'.repeat(4000)})))])assert.throws(()=>validateConversation(value));
});
test('ordinary chat and targeted clarification preserve prose without false write acknowledgements',()=>{
  assert.deepEqual(normalizeConversation({content:'Halo! Mau dibantu apa?'},input(),today),{type:'answer',content:'Halo! Mau dibantu apa?'});
  assert.equal(normalizeConversation({content:'Sudah saya simpan semua.'},input(),today).content,'Perubahan belum diterapkan. Periksa usulan dan setujui penyimpanannya di aplikasi.');
  assert.equal(normalizeConversation(tool('ask_clarification',{question:'Mau belajar jam berapa?'}),input(),today).reason,'conversation');
});
test('follow-up can quote the original user request while taking a time from the latest turn',()=>{
  const value=input([{role:'user',content:'Besok belajar satu jam'},{role:'assistant',content:'Jam berapa?'},{role:'user',content:'Jam 10 aja'}]);
  const item={action:'create_agenda',title:'Belajar',localDate:'2026-10-28',startLocal:'2026-10-28T10:00',deadlineLocal:null,durationMinutes:60,amountRupiah:null,transactionType:null,categoryId:null,transactionStatus:null,sourceQuote:'Besok belajar satu jam'};
  const response=normalizeConversation(tool('prepare_draft',{items:[item]}),value,today);
  assert.equal(response.type,'draft_proposal');assert.equal(response.items[0].startLocal,'2026-10-28T10:00');
  assert.throws(()=>normalizeConversation(tool('prepare_draft',{items:[{...item,sourceQuote:'invented'}]}),value,today));
  assert.match(conversationPrompt(today,[item]),/Usulan aktif/);
});
test('v2 turn retains fixed model, verifies auth/quota and forwards bounded context once',async()=>{
  let count=0;
  const body=input([{role:'user',content:'Halo'},{role:'assistant',content:'Halo juga'},{role:'user',content:'Bisa bantu apa?'}]);
  const request=new Request('https://ruma.invalid/v2/agent/turn',{method:'POST',headers:{Authorization:'Bearer fixture','Content-Type':'application/json'},body:JSON.stringify(body)});
  const response=await handle(request,{FIREBASE_PROJECT_ID:'demo-ruma',NARAROUTER_API_KEY:'fixture'},{verify:async()=>({uid:'owner'}),quota:async()=>{},fetch:async(_url,options)=>{count++;const v=JSON.parse(options.body);assert.equal(v.model,MODEL);assert.equal(v.messages.length,4);return Response.json({model:MODEL,choices:[{finish_reason:'stop',message:{content:'Aku bisa bantu agenda dan catatan uang.'}}]});}});
  assert.equal(response.status,200);assert.equal((await response.json()).type,'answer');assert.equal(count,1);
});
test('image extraction keeps incomplete rows visible and rejects fabricated schema/indices',()=>{
  const row={title:'Basis Data',weekday:2,start:'10:00',end:'11:40',location:'Lab 2',sourceImage:0,issue:null};
  assert.equal(normalizeSchedule(tool('extract_schedule',{rows:[row,{...row,title:null,start:null,issue:'Nama/jam buram'}],note:''}),1).rows.length,2);
  assert.throws(()=>normalizeSchedule(tool('extract_schedule',{rows:[{...row,sourceImage:1}],note:''}),1));
  const r=normalizeSchedule(tool('extract_schedule',{rows:[{...row,start:'25:00'}],note:''}),1).rows[0];assert.equal(r.start,null);assert.ok(r.issue);
});
test('image endpoint sends bounded binary image to the fixed provider; never accepts remote image URLs',async()=>{
  let count=0;
  const form=new FormData();form.append('images',new Blob([new Uint8Array([137,80,78,71,13,10,26,10,0])],{type:'image/png'}),'synthetic.png');
  const request=new Request('https://ruma.invalid/v2/agent/schedule',{method:'POST',headers:{Authorization:'Bearer fixture'},body:form});
  const response=await handle(request,{FIREBASE_PROJECT_ID:'demo-ruma',NARAROUTER_API_KEY:'fixture'},{verify:async()=>({uid:'owner'}),quota:async()=>{},fetch:async(_url,options)=>{count++;const v=JSON.parse(options.body);assert.match(v.messages[1].content[1].image_url.url,/^data:image\/png;base64,/);return Response.json({model:MODEL,choices:[{finish_reason:'tool_calls',message:tool('extract_schedule',{rows:[],note:'Tidak ada jadwal terbaca.'})}]});}});
  assert.equal(response.status,200);assert.equal((await response.json()).type,'schedule_extraction');assert.equal(count,1);
  const bad=new FormData();bad.append('images','https://private.invalid/image');
  const denied=await handle(new Request('https://ruma.invalid/v2/agent/schedule',{method:'POST',headers:{Authorization:'Bearer fixture'},body:bad}),{},{verify:async()=>({uid:'owner'}),fetch:()=>assert.fail()});assert.equal(denied.status,400);
});

test('cross-turn quotes and explicit WIB formatting normalize without allowing invented provenance',()=>{
 const value=input([{role:'user',content:'Besok belajar satu jam.'},{role:'user',content:'Jam 10 aja.'}]);
 const item={action:'create_agenda',title:'Belajar',localDate:'2026-10-28',startLocal:'2026-10-28T10:00 WIB',deadlineLocal:null,durationMinutes:60,amountRupiah:null,transactionType:null,categoryId:null,transactionStatus:null,sourceQuote:'Besok belajar satu jam. Jam 10 aja.'};
 assert.equal(normalizeConversation(tool('prepare_draft',{items:[item]}),value,today).items[0].startLocal,'2026-10-28T10:00');
 assert.throws(()=>normalizeConversation(tool('prepare_draft',{items:[{...item,sourceQuote:'Besok makan'}]}),value,today));
});
test('schedule corrections validate every row and reject ambiguity combined with changes',async()=>{
 const rows=[{index:0,title:'Basis Data',weekday:2,date:null,start:'10:00',end:'11:40',location:'Lab',included:true}];
 validateCorrectionRows(rows);
 assert.equal(normalizeCorrection(tool('correct_schedule',{updates:[{...rows[0],weekday:4}],question:''}),rows).updates[0].weekday,4);
 for(const updates of [[{...rows[0],index:1}],[rows[0],rows[0]],[{...rows[0],date:'invalid'}]])assert.throws(()=>normalizeCorrection(tool('correct_schedule',{updates,question:''}),rows));
 assert.throws(()=>normalizeCorrection(tool('correct_schedule',{updates:rows,question:'Yang mana?'}),rows));
 const request=new Request('https://ruma.invalid/v2/agent/schedule/correct',{method:'POST',headers:{Authorization:'Bearer fixture','Content-Type':'application/json'},body:JSON.stringify({...input(),rows})});
 const response=await handle(request,{FIREBASE_PROJECT_ID:'demo-ruma',NARAROUTER_API_KEY:'fixture'},{verify:async()=>({uid:'owner'}),quota:async()=>{},fetch:async(_url,options)=>{const v=JSON.parse(options.body);assert.equal(v.tool_choice.function.name,'correct_schedule');return Response.json({model:MODEL,choices:[{finish_reason:'tool_calls',message:tool('correct_schedule',{updates:[],question:'Pindah ke hari apa?'})}]});}});
 assert.equal(response.status,200);assert.equal((await response.json()).requestId,'request');
});
