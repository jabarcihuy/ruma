import {test,before,after,beforeEach} from 'node:test';
import {readFile,writeFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,getDocs,collection,setDoc,updateDoc,deleteDoc,serverTimestamp,Timestamp} from 'firebase/firestore';
let env;const cases=[];
before(async()=>{
 if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8086')throw Error('demo_ruma_only');
 env=await initializeTestEnvironment({projectId:'demo-ruma',firestore:{host:'127.0.0.1',port:8086,rules:await readFile(new URL(process.env.RUMA_WISHLIST_RULES==='1'?'../../config/firebase/firestore.wishlist.rules':process.env.RUMA_SAVINGS_RULES==='1'?'../../config/firebase/firestore.savings.rules':process.env.RUMA_FINAL_STAGES_RULES==='1'?'../../config/firebase/firestore.final-stages.rules':'../../config/firebase/firestore.assistant-memory.rules',import.meta.url),'utf8')}});
});
beforeEach(async()=>env.clearFirestore());
after(async()=>{await env?.cleanup();await writeFile(process.env.RUMA_QA_DIR?process.env.RUMA_QA_DIR+'/assistant-memory-rules.json':new URL('../../docs/qa/assistant-memory/rules-results.json',import.meta.url),JSON.stringify({project:'demo-ruma',productionWrites:0,cases},null,2));});
const db=uid=>uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
const data=(patch={})=>({schemaVersion:1,revision:1,payload:'{"synthetic":true}',updatedAt:serverTimestamp(),...patch});
const check=async(name,fn)=>{await fn();cases.push(name);};
test('owner workspace create/read/update with bounded version; no other assistant documents',()=>check('owner',async()=>{
 const d=db('owner'),r=doc(d,'users/owner/assistant/session');await assertSucceeds(setDoc(r,data()));await assertSucceeds(getDoc(r));await assertSucceeds(updateDoc(r,{revision:2,payload:'{"updated":true}',updatedAt:serverTimestamp()}));await assertFails(updateDoc(r,{revision:2,payload:'stale',updatedAt:serverTimestamp()}));await assertFails(deleteDoc(r));await assertFails(setDoc(doc(d,'users/owner/assistant/other'),data()));
}));
test('foreign and signed out sessions cannot read list or write workspace',()=>check('isolation',async()=>{
 await setDoc(doc(db('owner'),'users/owner/assistant/session'),data());
 for(const d of [db('other'),db(null)]) {
  await assertFails(getDoc(doc(d,'users/owner/assistant/session')));await assertFails(getDocs(collection(d,'users/owner/assistant')));await assertFails(setDoc(doc(d,'users/owner/assistant/session'),data()));
 }
}));
test('reject extra fields, unsupported schema, unbounded payload and fake timestamps',()=>check('validation',async()=>{
 const d=db('owner'),r=doc(d,'users/owner/assistant/session');
 for(const patch of [{schemaVersion:2},{revision:0},{revision:5},{revision:1.5},{payload:{}},{payload:'x'.repeat(160001)},{uid:'other'},{updatedAt:Timestamp.fromMillis(1)}]) await assertFails(setDoc(r,data(patch)));
 await assertSucceeds(setDoc(r,data({payload:'x'.repeat(160000)})));
}));
test('workspace never grants writes to agenda, money, receipts, usage or server inbox',()=>check('not-authority',async()=>{
 const d=db('owner');await setDoc(doc(d,'users/owner/assistant/session'),data({payload:'{"applied":true,"admin":true}'}));
 for(const path of ['users/owner/agenda/a','users/owner/transactions/t','users/owner/operations/op','users/owner/state/core','usage/global_day','users/owner/notifications/forged']) await assertFails(setDoc(doc(d,path),{fromAssistant:true}));
}));
