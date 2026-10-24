import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,runTransaction,Timestamp,serverTimestamp} from 'firebase/firestore';

const emulator=process.env.FIRESTORE_EMULATOR_HOST;
const projectId='demo-ruma';
const tomorrowJakarta=()=>new Date(Date.now()+31*3600000).toISOString().slice(0,10);
let environment;
const report={date:'2026-10-19',scope:'Local Firestore emulator; create-batch integration candidate only',projectId,productionWrites:0,cases:[]};
before(async()=>{
  if (!emulator || !/^127\.0\.0\.1:\d+$/.test(emulator)) throw new Error('Use local demo-ruma Firestore emulator only');
  const [host,port]=emulator.split(':');
  environment=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:await readFile(new URL('../../config/firebase/firestore.rules',import.meta.url),'utf8')}});
});
after(async()=>{
  await environment?.cleanup();
  report.overallPassed=report.cases.length===9 && report.cases.every(x=>x.passed);
  await writeFile(new URL('../../docs/qa/firestore-rules-check.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
});
beforeEach(async()=>{
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async context=>{
    const db=context.firestore();
    const base={schemaVersion:1,version:1,createdAt:Timestamp.now(),updatedAt:Timestamp.now()};
    await setDoc(doc(db,'users/owner/state/core'),{...base,agendaRevision:0,financeRevision:0,balanceRupiah:820000,lifetimeIncomeRupiah:2000000,lifetimeExpenseRupiah:1180000,lastUndoOperationId:null});
    await setDoc(doc(db,'users/owner/months/2026-10'),{...base,incomeRupiah:2000000,expenseRupiah:1180000,categoryExpenseRupiah:{food:640000,other:540000},budgetTotalRupiah:1500000,categoryBudgetRupiah:{},operationId:null});
    if (tomorrowJakarta().slice(0,7)!=='2026-10')
      await setDoc(doc(db,`users/owner/months/${tomorrowJakarta().slice(0,7)}`),{...base,incomeRupiah:2000000,expenseRupiah:1180000,categoryExpenseRupiah:{food:640000,other:540000},budgetTotalRupiah:1500000,categoryBudgetRupiah:{},operationId:null});
    await setDoc(doc(db,'users/owner/notifications/n1'),{title:'Synthetic',readAt:null,status:'sent'});
  });
});
async function check(name,fn) {
  const entry={name,passed:false};report.cases.push(entry);
  try {await fn();entry.passed=true;} catch(error) {entry.error=error.code??error.name;throw error;}
}
function base() {return {schemaVersion:1,version:1,createdAt:serverTimestamp(),updatedAt:serverTimestamp()};}
async function createBatch(db,{invalid=false,future=false,max=false,reminderOverride={},op='operation-1'}={}) {
  return runTransaction(db,async tx=>{
    const receiptRef=doc(db,`users/owner/operations/${op}`);
    const existing=await tx.get(receiptRef);
    if (existing.exists()) return existing.data().result;
    const localDate=future?tomorrowJakarta():'2026-10-18';
    const monthKey=localDate.slice(0,7);
    const coreRef=doc(db,'users/owner/state/core'),monthRef=doc(db,`users/owner/months/${monthKey}`);
    const current=await tx.get(coreRef),month=await tx.get(monthRef);
    const amounts=max?[18000,15000,5000]:[18000,15000];
    const total=amounts.reduce((a,b)=>a+b,0);
    const targets=[];
    const start=Date.parse('2026-10-20T03:00:00Z');
    for (let i=0;i<(max?3:2);i++) {
      const id=`a${i}`;targets.push(`agenda/${id}`);
      tx.set(doc(db,`users/owner/agenda/${id}`),{...base(),deletedAt:null,operationId:op,kind:'task',title:`Synthetic ${i}`,description:'',startAtUtc:Timestamp.fromMillis(start+i*3600000),endAtUtc:Timestamp.fromMillis(start+(i+1)*3600000),durationMinutes:60,deadlineAtUtc:null,priority:'normal',status:'planned',timezone:'Asia/Jakarta',recurrence:{type:'none'}});
      if (max) tx.set(doc(db,`users/owner/reminders/${id}`),{...base(),agendaId:id,occurrenceKey:`${id}:2026-10-20`,sourceVersion:1,generation:1,enabled:true,leadMinutes:10,message:'',eventAtUtc:Timestamp.fromMillis(start+i*3600000),dueAtUtc:Timestamp.fromMillis(start+i*3600000-600000),availableAtUtc:Timestamp.fromMillis(start+i*3600000-600000),status:'queued',dispatch:{},...reminderOverride});
    }
    for (let i=0;i<amounts.length;i++) {
      const id=`t${i}`;targets.push(`transactions/${id}`);
      tx.set(doc(db,`users/owner/transactions/${id}`),{...base(),deletedAt:null,operationId:op,type:'expense',amountRupiah:invalid&&i===0?-1:amounts[i],categoryId:i===0?'food':'other',localDate,monthKey,description:'Synthetic',source:'ai'});
    }
    tx.set(coreRef,{...current.data(),version:current.data().version+1,updatedAt:serverTimestamp(),agendaRevision:current.data().agendaRevision+1,financeRevision:current.data().financeRevision+1,balanceRupiah:current.data().balanceRupiah-total,lifetimeExpenseRupiah:current.data().lifetimeExpenseRupiah+total,lastUndoOperationId:op});
    tx.set(monthRef,{...month.data(),version:month.data().version+1,updatedAt:serverTimestamp(),expenseRupiah:month.data().expenseRupiah+total,categoryExpenseRupiah:{food:658000,other:month.data().categoryExpenseRupiah.other+total-18000},operationId:op});
    const result={amountRupiah:total};
    tx.set(receiptRef,{...base(),draftId:'synthetic-draft',approvedRevision:1,kind:'create_batch',targets,result,undoState:'available'});
    return result;
  });
}
test('owner can read; another UID and unauthenticated clients cannot',()=>check('account-isolation',async()=>{
  const own=environment.authenticatedContext('owner').firestore();
  const other=environment.authenticatedContext('other').firestore();
  const guest=environment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(own,'users/owner/state/core')));
  await assertFails(getDoc(doc(other,'users/owner/state/core')));
  await assertFails(getDoc(doc(guest,'users/owner/state/core')));
  await assertFails(setDoc(doc(other,'users/owner/agenda/intrusion'),{}));
}));
test('combined batch is atomic and retry does not duplicate money',()=>check('combined-idempotency',async()=>{
  const db=environment.authenticatedContext('owner').firestore();
  await assertSucceeds(createBatch(db));
  await assertSucceeds(createBatch(db));
  const core=(await getDoc(doc(db,'users/owner/state/core'))).data();
  const month=(await getDoc(doc(db,'users/owner/months/2026-10'))).data();
  assert.equal(core.balanceRupiah,787000);assert.equal(core.lifetimeExpenseRupiah,1213000);assert.equal(core.financeRevision,1);
  assert.equal(month.expenseRupiah,1213000);assert.equal(month.budgetTotalRupiah-month.expenseRupiah,287000);
}));
test('one invalid item rolls back every document and aggregate',()=>check('atomic-rollback',async()=>{
  const db=environment.authenticatedContext('owner').firestore();
  await assertFails(createBatch(db,{invalid:true}));
  assert.equal((await getDoc(doc(db,'users/owner/state/core'))).data().balanceRupiah,820000);
  assert.equal((await getDoc(doc(db,'users/owner/agenda/a0'))).exists(),false);
  assert.equal((await getDoc(doc(db,'users/owner/operations/operation-1'))).exists(),false);
}));
test('future financial dates are rejected by Rules even if client bypasses agent',()=>check('future-date-protection',async()=>{
  const db=environment.authenticatedContext('owner').firestore();
  await assertFails(createBatch(db,{future:true}));
  assert.equal((await getDoc(doc(db,'users/owner/state/core'))).data().balanceRupiah,820000);
}));
test('max 3 agenda + 3 transactions + 3 reminders and aggregates fit Rules checks',()=>check('maximum-create-batch',async()=>{
  const db=environment.authenticatedContext('owner').firestore();
  await assertSucceeds(createBatch(db,{max:true}));
  assert.equal((await getDoc(doc(db,'users/owner/state/core'))).data().balanceRupiah,782000);
  assert.equal((await getDoc(doc(db,'users/owner/reminders/a2'))).data().status,'queued');
}));
test('client cannot fabricate dispatch or point reminders at absent source',()=>check('reminder-protection',async()=>{
  const db=environment.authenticatedContext('owner').firestore();
  await assertFails(createBatch(db,{max:true,reminderOverride:{dispatch:{attempts:5,sentAt:Timestamp.now()}}}));
  await assertFails(createBatch(db,{max:true,reminderOverride:{agendaId:'another-user-item'}}));
}));
test('quota server documents are inaccessible even to logged-in owners',()=>check('server-quota-protection',async()=>{
  const db=environment.authenticatedContext('owner').firestore();
  await assertFails(getDoc(doc(db,'usage/owner_day')));
  await assertFails(setDoc(doc(db,'usage/owner_day'),{count:0}));
}));
test('inbox content cannot be forged; owner can mark own notification read',()=>check('inbox-protection',async()=>{
  const db=environment.authenticatedContext('owner').firestore();
  await assertSucceeds(updateDoc(doc(db,'users/owner/notifications/n1'),{readAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(db,'users/owner/notifications/n1'),{title:'Forged'}));
  await assertFails(setDoc(doc(db,'users/owner/notifications/new'),{title:'Fake push'}));
}));
test('unsupported paths and standalone financial writes stay denied',()=>check('default-deny',async()=>{
  const db=environment.authenticatedContext('owner').firestore();
  await assertFails(setDoc(doc(db,'users/owner/unplanned/new'),{value:1}));
  await assertFails(setDoc(doc(db,'users/owner/transactions/no-core'),{...base(),amountRupiah:1000}));
}));
