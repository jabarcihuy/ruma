import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,writeBatch,serverTimestamp} from 'firebase/firestore';
let env; const cases=[];
before(async()=>{const host=process.env.FIRESTORE_EMULATOR_HOST;if(!/^127\.0\.0\.1:\d+$/.test(host??''))throw Error('local_only');const [h,p]=host.split(':');env=await initializeTestEnvironment({projectId:'demo-ruma',firestore:{host:h,port:+p,rules:await readFile(new URL(process.env.RUMA_WISHLIST_RULES==='1'?'../../config/firebase/firestore.wishlist.rules':process.env.RUMA_SAVINGS_RULES==='1'?'../../config/firebase/firestore.savings.rules':process.env.RUMA_FINAL_STAGES_RULES==='1'?'../../config/firebase/firestore.final-stages.rules':process.env.RUMA_ASSISTANT_MEMORY_RULES==='1'?'../../config/firebase/firestore.assistant-memory.rules':process.env.RUMA_NOTIFICATIONS_RULES==='1'?'../../config/firebase/firestore.notifications.rules':'../../config/firebase/firestore.agent.rules',import.meta.url),'utf8')}})});
beforeEach(()=>env.clearFirestore());after(async()=>{await env?.cleanup();await writeFile(process.env.RUMA_QA_DIR ? process.env.RUMA_QA_DIR+'/batch-rules.json' : new URL('../../docs/qa/assistant/batch-rules.json',import.meta.url),JSON.stringify({productionWrites:0,cases},null,2))});
const base=()=>({schemaVersion:1,version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
const cats=()=>({food:0,transport:0,housing:0,other:0});const budgets=()=>({food:null,transport:null,housing:null,other:null});
const db=()=>env.authenticatedContext('owner').firestore();
async function run(name,fn){await fn();cases.push(name)}
async function commit(d,{ac=3,tc=3,prior=false,op='batch1',distinct=false,change=()=>{},omit,uid='owner'}={}){
 const docs=new Map(),a=Array.from({length:ac},(_,i)=>(prior?op:'')+'a'+i),t=Array.from({length:tc},(_,i)=>(prior?op:'')+'t'+i);
 for(const id of a)docs.set('agenda/'+id,{...base(),operationId:op,deletedAt:null,kind:'task',title:'Synthetic agenda',description:'',startAtUtc:null,endAtUtc:null,durationMinutes:60,deadlineAtUtc:null,priority:'normal',status:'planned',timezone:'Asia/Jakarta',recurrence:{type:'none'}});
 const months={};let income=0,expense=0;
 for(const [i,id] of t.entries()){
 const type=i===0?'income':'expense',amountRupiah=10000*(i+1),categoryId=i===0?'allowance':i===1?'food':'transport',monthKey=distinct?['2026-08','2026-09','2026-10'][i]:'2026-10';
 docs.set('transactions/'+id,{...base(),operationId:op,deletedAt:null,type,amountRupiah,categoryId,localDate:monthKey+'-01',monthKey,description:'Synthetic money',source:'ai'});
 const m=months[monthKey]??={...base(),operationId:op,incomeRupiah:0,expenseRupiah:0,categoryExpenseRupiah:cats(),budgetTotalRupiah:null,categoryBudgetRupiah:budgets()};
 if(type==='income'){income+=amountRupiah;m.incomeRupiah+=amountRupiah}else{expense+=amountRupiah;m.expenseRupiah+=amountRupiah;m.categoryExpenseRupiah[categoryId]+=amountRupiah}
 }
 for(const [key,value] of Object.entries(months))docs.set('months/'+key,value);
 docs.set('state/core',{...base(),agendaRevision:ac?1:0,financeRevision:tc?1:0,balanceRupiah:income-expense,lifetimeIncomeRupiah:income,lifetimeExpenseRupiah:expense,lastUndoOperationId:op});
 docs.set('operations/'+op,{...base(),draftId:'draft1',approvedRevision:1,kind:'create_batch',targets:[...a.map(x=>'agenda/'+x),...t.map(x=>'transactions/'+x)],result:{agendaIds:a,transactionIds:t,requestKey:'synthetic-approved-revision'},undoState:'unavailable'});
 if(prior){
  const old=(await getDoc(doc(d,`users/${uid}/state/core`))).data(),next=docs.get('state/core');
  Object.assign(next,{version:old.version+1,createdAt:old.createdAt,agendaRevision:old.agendaRevision+(ac?1:0),financeRevision:old.financeRevision+(tc?1:0),balanceRupiah:old.balanceRupiah+next.balanceRupiah,lifetimeIncomeRupiah:old.lifetimeIncomeRupiah+income,lifetimeExpenseRupiah:old.lifetimeExpenseRupiah+expense});
  for(const key of Object.keys(months)){const before=(await getDoc(doc(d,`users/${uid}/months/${key}`))).data();if(before){const m=docs.get('months/'+key);Object.assign(m,{version:before.version+1,createdAt:before.createdAt,incomeRupiah:before.incomeRupiah+m.incomeRupiah,expenseRupiah:before.expenseRupiah+m.expenseRupiah,budgetTotalRupiah:before.budgetTotalRupiah,categoryBudgetRupiah:before.categoryBudgetRupiah,categoryExpenseRupiah:Object.fromEntries(Object.keys(cats()).map(c=>[c,before.categoryExpenseRupiah[c]+m.categoryExpenseRupiah[c]]))})}}
 }
 change(docs);const batch=writeBatch(d);for(const [path,value] of docs)if(path!==omit)batch.set(doc(d,`users/${uid}/${path}`),value);return batch.commit();
}
const core=async d=>(await getDoc(doc(d,'users/owner/state/core'))).data();
test('six items, same month, exact totals',()=>run('3+3 same month',async()=>{const d=db();await commit(d);assert.equal((await core(d)).balanceRupiah,-40000)}));
test('six items across three months',()=>run('3+3 three months',async()=>{await commit(db(),{distinct:true})}));
test('only agenda or only money',()=>run('single domain',async()=>{await commit(db(),{tc:0});await env.clearFirestore();await commit(db(),{ac:0})}));
test('one invalid target rolls back all writes',()=>run('atomic rollback',async()=>{const d=db();await assertFails(commit(d,{change:m=>m.get('agenda/a2').durationMinutes=0}));assert.equal(await core(d),undefined)}));
test('missing target or month rejected',()=>run('missing dependency',async()=>{for(const omit of ['agenda/a2','transactions/t2','months/2026-10','operations/batch1','state/core'])await assertFails(commit(db(),{omit}))}));
test('forged summaries cannot pass',()=>run('arithmetic forgery',async()=>{for(const change of [m=>m.get('state/core').balanceRupiah++,m=>{m.get('state/core').lifetimeIncomeRupiah++;m.get('state/core').balanceRupiah++},m=>m.get('state/core').agendaRevision++,m=>{const x=m.get('months/2026-10');x.expenseRupiah++;x.categoryExpenseRupiah.food++},m=>m.get('months/2026-10').budgetTotalRupiah=10])await assertFails(commit(db(),{change}))}));
test('manifest duplicates, extra targets and max items rejected',()=>run('manifest boundary',async()=>{for(const change of [m=>m.get('operations/batch1').result.agendaIds.push('a0'),m=>m.get('operations/batch1').targets[0]='agenda/unlisted',m=>m.get('operations/batch1').result.transactionIds.pop(),m=>m.get('transactions/t0').source='manual'])await assertFails(commit(db(),{change}));await assertFails(commit(db(),{ac:4}));await assertFails(commit(db(),{ac:0,tc:0}))}));
test('foreign owner cannot write; existing target cannot be reused',()=>run('ownership immutable identities',async()=>{const d=db();await assertFails(commit(d,{uid:'other'}));await commit(d);await assertFails(commit(d,{op:'different'}));assert.equal((await core(d)).version,1)}));

test('append to existing ledger preserves previous totals and versions',()=>run('existing ledger batch',async()=>{const d=db();await commit(d);await commit(d,{prior:true,op:'batch2',distinct:true});assert.equal((await core(d)).balanceRupiah,-80000);assert.equal((await core(d)).version,2);const m=(await getDoc(doc(d,'users/owner/months/2026-10'))).data();assert.equal(m.expenseRupiah,80000);assert.equal(m.version,2)}));
test('unlisted extra writes are rejected',()=>run('unlisted target',async()=>{await assertFails(commit(db(),{change:m=>m.set('transactions/extra',{...m.get('transactions/t1')})}))}));
