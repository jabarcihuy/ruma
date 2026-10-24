import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,writeBatch,serverTimestamp,Timestamp} from 'firebase/firestore';
let env;const cases=[];
before(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8086')throw Error('local_demo_only');
 env=await initializeTestEnvironment({projectId:'demo-ruma',firestore:{host:'127.0.0.1',port:8086,rules:await readFile(new URL(process.env.RUMA_WISHLIST_RULES==='1'?'../../config/firebase/firestore.wishlist.rules':process.env.RUMA_SAVINGS_RULES==='1'?'../../config/firebase/firestore.savings.rules':process.env.RUMA_FINAL_STAGES_RULES==='1'?'../../config/firebase/firestore.final-stages.rules':process.env.RUMA_ASSISTANT_MEMORY_RULES==='1'?'../../config/firebase/firestore.assistant-memory.rules':'../../config/firebase/firestore.notifications.rules',import.meta.url),'utf8')}});
});
after(async()=>{await env?.cleanup();await writeFile(process.env.RUMA_QA_DIR ? process.env.RUMA_QA_DIR+'/notification-rules-results.json' : new URL('../../docs/qa/notifications/rules-results.json',import.meta.url),JSON.stringify({project:'demo-ruma',productionWrites:0,cases},null,2));});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async ctx=>{
 const d=ctx.firestore(),stamp=Timestamp.now(),start=Date.now()+3600000;
 await setDoc(doc(d,'users/owner/agenda/a'),{schemaVersion:1,version:1,createdAt:stamp,updatedAt:stamp,deletedAt:null,operationId:'seed',kind:'task',title:'Synthetic',description:'',
  startAtUtc:Timestamp.fromMillis(start),endAtUtc:Timestamp.fromMillis(start+3600000),durationMinutes:60,deadlineAtUtc:null,priority:'normal',status:'planned',timezone:'Asia/Jakarta',recurrence:{type:'none'}});
 await setDoc(doc(d,'users/owner/state/core'),{schemaVersion:1,version:1,createdAt:stamp,updatedAt:stamp,agendaRevision:1,financeRevision:0,balanceRupiah:0,lifetimeIncomeRupiah:0,lifetimeExpenseRupiah:0,lastUndoOperationId:'seed'});
});});
const db=()=>env.authenticatedContext('owner').firestore();
const check=async(name,fn)=>{await fn();cases.push(name);};
async function job(d,changes={}){
 const a=(await getDoc(doc(d,'users/owner/agenda/a'))).data();
 return {schemaVersion:1,agendaId:'a',sourceVersion:1,generation:1,enabled:true,leadMinutes:10,anchorAtUtc:a.startAtUtc,
  dueAtUtc:Timestamp.fromMillis(a.startAtUtc.toMillis()-600000),availableAtUtc:Timestamp.fromMillis(a.startAtUtc.toMillis()-600000),
  createdAt:serverTimestamp(),updatedAt:serverTimestamp(),status:'queued',attempts:0,leaseId:null,leaseUntilUtc:null,lastError:null,deviceResults:{},...changes};
}
test('owner can configure and disable a future reminder; cannot forge dispatch or another target',()=>check('config-and-boundary',async()=>{
 const d=db(),r=doc(d,'users/owner/reminders/a');await assertSucceeds(setDoc(r,await job(d)));
 await assertFails(updateDoc(r,{status:'sent',attempts:1}));
 await assertFails(updateDoc(r,{sourceVersion:99}));
 await assertFails(updateDoc(r,{generation:2,deviceResults:{evil:'sent'},updatedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(r,{generation:2,enabled:false,status:'cancelled',updatedAt:serverTimestamp()}));
}));
test('device fields restricted, token and inbox belong to owner',()=>check('device-inbox-isolation',async()=>{
 const d=db(),r=doc(d,'users/owner/devices/installation');
 await assertSucceeds(setDoc(r,{token:'synthetic-registration-token',enabled:true,platform:'android',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(r,{uid:'other'}));
 await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),'users/owner/devices/installation')));
 await assertFails(setDoc(doc(d,'users/owner/notifications/forged'),{agendaId:'a'}));
 await env.withSecurityRulesDisabled(async ctx=>setDoc(doc(ctx.firestore(),'users/owner/notifications/a_1'),{agendaId:'a',readAt:null}));
 await assertSucceeds(updateDoc(doc(d,'users/owner/notifications/a_1'),{readAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(d,'users/owner/notifications/a_1'),{agendaId:'other'}));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users/owner/notifications/a_1')));
}));
async function changeAgenda(d,includeReminder){
 const a=(await getDoc(doc(d,'users/owner/agenda/a'))).data(),c=(await getDoc(doc(d,'users/owner/state/core'))).data();
 const b=writeBatch(d);b.set(doc(d,'users/owner/agenda/a'),{...a,version:2,updatedAt:serverTimestamp(),operationId:'change',title:'Updated'});
 b.set(doc(d,'users/owner/state/core'),{...c,version:2,updatedAt:serverTimestamp(),agendaRevision:2,lastUndoOperationId:'change'});
 b.set(doc(d,'users/owner/operations/change'),{schemaVersion:1,version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),draftId:'manual',approvedRevision:1,kind:'agenda_update',targets:['agenda/a'],result:{agendaId:'a',version:2,requestKey:'synthetic'},undoState:'unavailable'});
 if(includeReminder)b.update(doc(d,'users/owner/reminders/a'),{sourceVersion:2,updatedAt:serverTimestamp()});
 return b.commit();
}
test('agenda mutation with existing job must update source version atomically',()=>check('atomic-source-update',async()=>{
 const d=db();await setDoc(doc(d,'users/owner/reminders/a'),await job(d));
 await assertFails(changeAgenda(d,false));await assertSucceeds(changeAgenda(d,true));
 assert.equal((await getDoc(doc(d,'users/owner/reminders/a'))).data().sourceVersion,2);
}));
test('invalid due, lead, agenda ID and status cannot queue',()=>check('invalid-config',async()=>{
 const d=db();for(const patch of [{leadMinutes:0},{leadMinutes:11},{agendaId:'other'},{dueAtUtc:Timestamp.now()},{status:'leased'},{attempts:3},{generation:9}])await assertFails(setDoc(doc(d,'users/owner/reminders/a'),await job(d,patch)));
}));
