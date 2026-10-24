import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,getDocs,collection,query,where,setDoc,updateDoc,deleteDoc,runTransaction,Timestamp,serverTimestamp} from 'firebase/firestore';
let env;
const report={date:process.env.RUMA_QA_DIR ? '2026-10-20':'2026-10-19',projectId:'demo-ruma',productionWrites:0,cases:[]};
before(async()=>{
  const host=process.env.FIRESTORE_EMULATOR_HOST;
  if(!host||!/^127\.0\.0\.1:\d+$/.test(host))throw Error('Use the local demo-ruma emulator');
  const [hostname,port]=host.split(':');
  env=await initializeTestEnvironment({projectId:'demo-ruma',firestore:{host:hostname,port:Number(port),rules:await readFile(new URL(process.env.RUMA_WISHLIST_RULES==='1'?'../../config/firebase/firestore.wishlist.rules':process.env.RUMA_SAVINGS_RULES==='1'?'../../config/firebase/firestore.savings.rules':process.env.RUMA_FINAL_STAGES_RULES==='1'?'../../config/firebase/firestore.final-stages.rules':process.env.RUMA_ASSISTANT_MEMORY_RULES==='1'?'../../config/firebase/firestore.assistant-memory.rules':process.env.RUMA_NOTIFICATIONS_RULES==='1'?'../../config/firebase/firestore.notifications.rules':process.env.RUMA_AGENT_RULES==='1'?'../../config/firebase/firestore.agent.rules':process.env.RUMA_FINANCE_RULES==='1'?'../../config/firebase/firestore.finance.rules':'../../config/firebase/firestore.agenda.rules',import.meta.url),'utf8')}});
});
beforeEach(async()=>env.clearFirestore());
after(async()=>{await env?.cleanup();report.passed=report.cases.filter(x=>x.passed).length;report.failed=report.cases.filter(x=>!x.passed).length;await writeFile(process.env.RUMA_QA_DIR ? process.env.RUMA_QA_DIR+'/agenda-rules.json' : new URL(process.env.RUMA_NOTIFICATIONS_RULES==='1'?'../../docs/qa/notifications/agenda-regression.json':process.env.RUMA_AGENT_RULES==='1'?'../../docs/qa/assistant/agenda-regression.json':process.env.RUMA_FINANCE_RULES==='1'?'../../docs/qa/finance/agenda-regression.json':'../../docs/qa/agenda/rules-results.json',import.meta.url),JSON.stringify(report,null,2)+'\n');});
const db=()=>env.authenticatedContext('owner').firestore();
const base=()=>({schemaVersion:1,version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
async function check(name,fn){const c={name,passed:false};report.cases.push(c);await fn();c.passed=true;}
function input(){return {deletedAt:null,kind:'task',title:'Synthetic agenda',description:'',startAtUtc:Timestamp.fromMillis(Date.parse('2026-10-23T03:00:00Z')),endAtUtc:Timestamp.fromMillis(Date.parse('2026-10-23T04:00:00Z')),durationMinutes:60,deadlineAtUtc:null,priority:'normal',status:'planned',timezone:'Asia/Jakarta',recurrence:{type:'none'}};}
async function mutate(database,{id='a1',op='op1',change={},remove=false,expectedRevision,coreChange={},receiptChange={},omitAgenda=false,omitReceipt=false}={}){
 return runTransaction(database,async tx=>{
  const ar=doc(database,`users/owner/agenda/${id}`),cr=doc(database,'users/owner/state/core'),or=doc(database,`users/owner/operations/${op}`);
  const prior=await tx.get(or);if(prior.exists())return prior.data().result;
  const c=await tx.get(cr),a=await tx.get(ar);const old=c.data(),previous=a.data();
  if(expectedRevision!==undefined&&(old?.agendaRevision??0)!==expectedRevision)throw Error('stale');
  const version=(previous?.version??0)+1;
  const agenda=remove?{...previous,version,updatedAt:serverTimestamp(),operationId:op,deletedAt:serverTimestamp(),...change}
   :{...base(),...input(),...previous,version,updatedAt:serverTimestamp(),operationId:op,...change};
  if(!omitAgenda)tx.set(ar,agenda);
  tx.set(cr,{...base(),...old,version:(old?.version??0)+1,updatedAt:serverTimestamp(),agendaRevision:(old?.agendaRevision??0)+1,financeRevision:old?.financeRevision??0,balanceRupiah:old?.balanceRupiah??0,lifetimeIncomeRupiah:old?.lifetimeIncomeRupiah??0,lifetimeExpenseRupiah:old?.lifetimeExpenseRupiah??0,lastUndoOperationId:op,...coreChange});
  const result={agendaId:id,version,requestKey:'synthetic-request'};
  if(!omitReceipt)tx.set(or,{...base(),draftId:'manual',approvedRevision:1,kind:remove?'agenda_delete':previous?'agenda_update':'agenda_create',targets:[`agenda/${id}`],result,undoState:'unavailable',...receiptChange});
  return result;
 });
}
test('first agenda initializes core atomically; same receipt does not duplicate',()=>check('create-and-idempotent-retry',async()=>{
 const d=db();await assertSucceeds(mutate(d));await assertSucceeds(mutate(d));assert.equal((await getDoc(doc(d,'users/owner/state/core'))).data().agendaRevision,1);assert.equal((await getDocs(collection(d,'users/owner/agenda'))).size,1);
}));
test('owner list works; cross-account and unauthenticated reads/writes are denied',()=>check('account-isolation',async()=>{
 const d=db();await mutate(d);await assertSucceeds(getDocs(query(collection(d,'users/owner/agenda'),where('deletedAt','==',null))));
 for(const outsider of [env.authenticatedContext('other').firestore(),env.unauthenticatedContext().firestore()]){
  await assertFails(getDoc(doc(outsider,'users/owner/agenda/a1')));await assertFails(getDocs(collection(outsider,'users/owner/agenda')));await assertFails(mutate(outsider,{id:'intrusion'}));
 }
}));
test('edit and complete increment entity version and agenda revision',()=>check('edit-complete',async()=>{
 const d=db();await mutate(d);await assertSucceeds(mutate(d,{op:'op2',change:{title:'Updated'}}));await assertSucceeds(mutate(d,{op:'op3',change:{status:'completed'}}));
 const a=(await getDoc(doc(d,'users/owner/agenda/a1'))).data();assert.equal(a.title,'Updated');assert.equal(a.version,3);assert.equal(a.status,'completed');assert.equal((await getDoc(doc(d,'users/owner/state/core'))).data().agendaRevision,3);
}));
test('soft delete is atomic and tombstones cannot be edited or hard deleted',()=>check('soft-delete',async()=>{
 const d=db();await mutate(d);await assertSucceeds(mutate(d,{op:'delete1',remove:true}));assert.equal((await getDocs(query(collection(d,'users/owner/agenda'),where('deletedAt','==',null)))).size,0);
 if(process.env.RUMA_AGENT_RULES==='1') { await assertFails(mutate(d,{op:'forged-restore',change:{deletedAt:null,title:'Changed while restoring'}})); await assertSucceeds(mutate(d,{op:'resurrect',change:{deletedAt:null}})); } else await assertFails(mutate(d,{op:'resurrect',change:{deletedAt:null}}));await assertFails(deleteDoc(doc(d,'users/owner/agenda/a1')));
}));
test('missing receipt or missing entity rolls back the whole operation',()=>check('coupled-write',async()=>{
 const d=db();await assertFails(mutate(d,{omitReceipt:true}));await assertFails(mutate(d,{omitAgenda:true}));assert.equal((await getDoc(doc(d,'users/owner/state/core'))).exists(),false);
}));
test('invalid shape, duration, paired time, deadline, class and zone are rejected',()=>check('field-validation',async()=>{
 const d=db();for(const change of [{extra:'x'},{title:'  '},{durationMinutes:0},{endAtUtc:null},{kind:'class',startAtUtc:null,endAtUtc:null},{timezone:'UTC'},{deadlineAtUtc:Timestamp.fromMillis(1)},{status:'unknown'},{recurrence:{type:'weekly'}}])await assertFails(mutate(d,{change}));
 assert.equal((await getDoc(doc(d,'users/owner/agenda/a1'))).exists(),false);
}));
test('unscheduled tasks are supported',()=>check('unscheduled-task',async()=>{
 await assertSucceeds(mutate(db(),{change:{startAtUtc:null,endAtUtc:null,deadlineAtUtc:Timestamp.fromMillis(Date.parse('2026-11-01T12:00:00Z'))}}));
}));
test('agenda operations cannot forge balances or finance revisions',()=>check('finance-protection',async()=>{
 const d=db();await mutate(d);for(const coreChange of [{balanceRupiah:1000,lifetimeIncomeRupiah:1000},{financeRevision:1},{agendaRevision:9}])await assertFails(mutate(d,{op:'op2',coreChange}));
 assert.equal((await getDoc(doc(d,'users/owner/state/core'))).data().balanceRupiah,0);
}));
test('created timestamps and operation receipts are immutable',()=>check('immutable-metadata',async()=>{
 const d=db();await mutate(d);await assertFails(mutate(d,{op:'op2',change:{createdAt:Timestamp.fromMillis(1)}}));await assertFails(updateDoc(doc(d,'users/owner/operations/op1'),{kind:'agenda_delete'}));await assertFails(deleteDoc(doc(d,'users/owner/operations/op1')));
}));
test('wrong receipt target or version cannot authorize changes',()=>check('receipt-validation',async()=>{
 const d=db();await assertFails(mutate(d,{receiptChange:{targets:['agenda/other']}}));await assertFails(mutate(d,{receiptChange:{result:{agendaId:'other',version:1,requestKey:'synthetic'}}}));
}));
test('concurrent submissions against the same revision have one winner',()=>check('concurrent-revision',async()=>{
 const d=db();const result=await Promise.allSettled([mutate(d,{id:'a1',op:'op1',expectedRevision:0}),mutate(d,{id:'a2',op:'op2',expectedRevision:0})]);assert.equal(result.filter(x=>x.status==='fulfilled').length,1);assert.equal((await getDocs(collection(d,'users/owner/agenda'))).size,1);
}));
test('all unsupported feature and server paths remain closed',()=>check('default-deny',async()=>{
 const d=db();for(const path of ['usage/owner_day','users/owner/transactions/t1','users/owner/reminders/r1','users/owner/devices/d1','users/owner/conversations/c1']){await assertFails(setDoc(doc(d,path),{value:1}));if((process.env.RUMA_FINANCE_RULES==='1'||process.env.RUMA_AGENT_RULES==='1') && (path==='users/owner/transactions/t1' || process.env.RUMA_NOTIFICATIONS_RULES==='1' && ['users/owner/reminders/r1','users/owner/devices/d1'].includes(path)))await assertSucceeds(getDoc(doc(d,path)));else await assertFails(getDoc(doc(d,path)));}
}));
