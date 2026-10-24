import {test} from 'node:test';
import assert from 'node:assert/strict';
import {normalizeDraft,AGENT_TOOLS} from '../src/agent.mjs';
import {patchFields} from '../src/record-tools.mjs';
const call=(name,args)=>({tool_calls:[{id:'c',type:'function',function:{name,arguments:JSON.stringify(args)}}]});
const patch=values=>({...Object.fromEntries(Object.keys(patchFields).map(k=>[k,null])),...values});
const change=()=>({recordType:'agenda',action:'update',targetTitle:'Belajar',targetDate:null,
 sourceQuote:'Ubah Belajar jadi 30 menit',patch:patch({durationMinutes:30})});
test('read queries and change drafts are bounded, never model-authored answers or commits',()=>{
 assert.equal(AGENT_TOOLS.length,4);
 assert.equal(normalizeDraft(call('read_records',{kind:'summary',date:'2026-10',categoryId:null}),'laporan','2026-10-20').type,'read_request');
 assert.equal(normalizeDraft(call('prepare_change',change()),change().sourceQuote,'2026-10-20').type,'change_proposal');
 assert.equal(normalizeDraft(call('ask_clarification',{reason:'one_change'}),'ubah beberapa','2026-10-20').reason,'one_change');
});
test('reject forged paths, malformed dates, unsafe changes and delete payload edits',()=>{
 for(const a of [
   {...change(),targetId:'other'}, {...change(),sourceQuote:'invented'}, {...change(),targetTitle:'Different'},
   {...change(),targetDate:'2026-02-30'}, {...change(),patch:patch({startLocal:'2026-10-20T25:00'})},
   {...change(),action:'delete'}, {...change(),patch:patch({amountRupiah:100})},
   {...change(),patch:patch({durationMinutes:30.5})},
 ]) assert.throws(()=>normalizeDraft(call('prepare_change',a),change().sourceQuote,'2026-10-20'));
 for(const q of [ {kind:'summary',date:'2026-13',categoryId:null}, {kind:'agenda',date:'2026-02-30',categoryId:null},
   {kind:'summary',date:'2026-10',categoryId:null,uid:'other'} ])
   assert.throws(()=>normalizeDraft(call('read_records',q),'q','2026-10-20'));
});
test('transactions require old date, delete has no replacement fields',()=>{
 const a={...change(),recordType:'transaction',targetDate:'2026-10-01',action:'delete',patch:patch({})};
 assert.equal(normalizeDraft(call('prepare_change',a),a.sourceQuote,'2026-10-20').type,'change_proposal');
 assert.throws(()=>normalizeDraft(call('prepare_change',{...a,targetDate:null}),a.sourceQuote,'2026-10-20'));
});
