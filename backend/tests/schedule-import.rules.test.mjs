import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,writeBatch,setDoc,getDoc,serverTimestamp,Timestamp} from 'firebase/firestore';
let env;
before(async()=>{
  if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8086')throw Error('demo_ruma_only');
  env=await initializeTestEnvironment({projectId:'demo-ruma',firestore:{host:'127.0.0.1',port:8086,rules:await readFile(new URL('../../config/firebase/firestore.wishlist.rules',import.meta.url),'utf8')}});
});
beforeEach(async()=>env.clearFirestore());
after(async()=>env?.cleanup());
const old=Timestamp.fromDate(new Date('2026-10-01T00:00:00Z'));
const source={provider:'image',key:'image:'+'a'.repeat(64),version:'',calendarKey:'',fingerprint:'b'.repeat(64),remote:{}};
const agenda=(index,operation,version=1)=>({schemaVersion:1,version,createdAt:version===1?serverTimestamp():old,updatedAt:serverTimestamp(),deletedAt:null,operationId:operation,
  kind:'class',title:`Kuliah ${index}`,description:'',startAtUtc:Timestamp.fromDate(new Date('2026-11-02T01:00:00Z')),endAtUtc:Timestamp.fromDate(new Date('2026-11-02T02:40:00Z')),
  durationMinutes:100,deadlineAtUtc:null,priority:'normal',status:'planned',timezone:'Asia/Jakarta',recurrence:{type:'weekly',originDate:'2026-11-02',untilLocalDate:'2027-03-31',exceptions:'{}',changes:'{}'},importSource:{...source,key:'image:'+String(index).padStart(64,'0')}});
const core=(operation,update=false)=>({schemaVersion:1,version:update?2:1,createdAt:update?old:serverTimestamp(),updatedAt:serverTimestamp(),agendaRevision:update?2:1,financeRevision:0,balanceRupiah:0,lifetimeIncomeRupiah:0,lifetimeExpenseRupiah:0,lastUndoOperationId:operation});
async function commit(count,{uid='owner',omit='',update=false,reminders=false,resultPatch={}}={}) {
  const db=env.authenticatedContext(uid).firestore(),batch=writeBatch(db),op=update?'update':'import',ids=Array.from({length:count},(_,i)=>`a${i}`);
  for(let i=0;i<count;i++)if(omit!==`a${i}`){batch.set(doc(db,`users/owner/agenda/a${i}`),agenda(i,op,update?2:1));if(reminders)batch.update(doc(db,`users/owner/reminders/a${i}`),{sourceVersion:2,updatedAt:serverTimestamp()});}
  if(omit!=='core')batch.set(doc(db,'users/owner/state/core'),core(op,update));
  if(omit!=='receipt')batch.set(doc(db,`users/owner/operations/${op}`),{schemaVersion:1,version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),draftId:'draft',approvedRevision:1,kind:'schedule_import',targets:ids,result:{ids,versions:ids.map(()=>update?2:1),requestKey:'synthetic-approved-request',...resultPatch},undoState:'unavailable'});
  return batch.commit();
}
test('eight recurring classes commit together with a complete receipt and unchanged finances',async()=>{
  await assertSucceeds(commit(8));
  const db=env.authenticatedContext('owner').firestore();
  assert.equal((await getDoc(doc(db,'users/owner/agenda/a7'))).data().recurrence.type,'weekly');
  assert.equal((await getDoc(doc(db,'users/owner/state/core'))).data().balanceRupiah,0);
});
test('missing item, receipt or core and a false receipt version cannot partially commit',async()=>{
  for(const omit of ['a2','core','receipt']){await env.clearFirestore();await assertFails(commit(3,{omit}));const db=env.authenticatedContext('owner').firestore();assert.equal((await getDoc(doc(db,'users/owner/agenda/a0'))).exists(),false);}
  await assertFails(commit(2,{resultPatch:{versions:[1,2]}}));
});
test('other UID and more than eight items are rejected',async()=>{
  await assertFails(commit(1,{uid:'other'}));await assertFails(commit(9));
});
test('refresh updates six classes and preserves reminder coupling within access budgets',async()=>{
  await env.withSecurityRulesDisabled(async c=>{
    const db=c.firestore();
    const c0={...core('previous'),version:1,agendaRevision:1,createdAt:old,updatedAt:old};await setDoc(doc(db,'users/owner/state/core'),c0);
    for(let i=0;i<6;i++){
      const a={...agenda(i,'previous'),createdAt:old,updatedAt:old};await setDoc(doc(db,`users/owner/agenda/a${i}`),a);
      const anchor=a.startAtUtc,due=Timestamp.fromMillis(anchor.toMillis()-600000);
      await setDoc(doc(db,`users/owner/reminders/a${i}`),{schemaVersion:1,agendaId:`a${i}`,sourceVersion:1,generation:1,enabled:false,leadMinutes:10,anchorAtUtc:anchor,dueAtUtc:due,occurrenceDate:'2026-11-02',createdAt:old,updatedAt:old,availableAtUtc:due,status:'cancelled',attempts:0,leaseId:null,leaseUntilUtc:null,lastError:null,deviceResults:{}});
    }
  });
  await assertSucceeds(commit(6,{update:true,reminders:true}));
  const db=env.authenticatedContext('owner').firestore();assert.equal((await getDoc(doc(db,'users/owner/reminders/a5'))).data().sourceVersion,2);
});
