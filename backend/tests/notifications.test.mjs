import {test} from 'node:test';
import assert from 'node:assert/strict';
import {dispatchReminders,fcmPayload} from '../src/notifications.mjs';
const now=new Date('2026-10-21T01:00:00Z');
class Memory {
 constructor(){this.docs=new Map();this.revision=0;}
 async get(path){return structuredClone(this.docs.get(path)??null);}
 put(path,data){this.docs.set(path,{path,data,version:String(++this.revision)});}
 async commit(writes){
  for(const w of writes){const d=this.docs.get(w.path);if(w.version?d?.version!==w.version:!!d)throw Error('conflict');}
  for(const w of writes)this.put(w.path,w.data);
 }
 async query(parent,q){return [...this.docs.values()].filter(d=>parent?d.path.startsWith(parent+'/devices/')&&d.data.enabled:
  d.path.includes('/reminders/')&&['queued','leased'].includes(d.data.status)&&d.data.availableAtUtc<=now).slice(0,q.limit).map(x=>structuredClone(x));}
}
function setup(){
 const db=new Memory(),anchor=new Date(+now+600000);
 db.put('users/u/agenda/a',{version:1,deletedAt:null,status:'planned',startAtUtc:anchor,deadlineAtUtc:null});
 db.put('users/u/reminders/a',{agendaId:'a',sourceVersion:1,generation:1,enabled:true,leadMinutes:10,anchorAtUtc:anchor,dueAtUtc:now,
  availableAtUtc:now,status:'queued',attempts:0,leaseId:null,leaseUntilUtc:null,lastError:null,deviceResults:{}});
 db.put('users/u/devices/d',{enabled:true,token:'synthetic-registration-token'});return db;
}
const env={FIREBASE_PROJECT_ID:'demo-ruma',NOTIFICATIONS_ENABLED:'true'};
const run=(db,fetch)=>dispatchReminders(env,{db,token:'synthetic-oauth',now,fetch});
test('disabled cron makes no reads or sends',async()=>assert.deepEqual(await dispatchReminders({}),{disabled:true,processed:0}));
test('generic payload, stable tag and exact owner; send creates one inbox, next tick does not duplicate',async()=>{
 const db=setup();let calls=0;
 const sender=async(url,o)=>{calls++;const m=JSON.parse(o.body).message;assert.equal(m.token,'synthetic-registration-token');assert.equal(m.data.uid,'u');assert.equal(m.android.notification.tag,'a_1');assert.equal(m.android.ttl,'600s');assert.ok(!JSON.stringify(m).includes('money'));return Response.json({name:'sent'});};
 assert.equal((await run(db,sender)).sent,1);await run(db,sender);assert.equal(calls,1);
 assert.equal(db.docs.get('users/u/reminders/a').data.status,'sent');assert.ok(await db.get('users/u/notifications/a_1'));
});
test('two concurrent ticks have one lease winner',async()=>{
 const db=setup();let calls=0;await Promise.all([run(db,async()=>{calls++;return Response.json({name:'sent'});}),run(db,async()=>{calls++;return Response.json({name:'sent'});})]);assert.equal(calls,1);
});
test('completed/deleted/moved and expired sources never send',async()=>{
 for(const patch of [{status:'completed'},{deletedAt:now},{version:2},{startAtUtc:new Date(+now+900000)}]){
  const db=setup();db.put('users/u/agenda/a',{...(await db.get('users/u/agenda/a')).data,...patch});
  await run(db,()=>assert.fail('stale source sent'));assert.equal((await db.get('users/u/reminders/a')).data.status,'cancelled');
 }
 const db=setup();const j=await db.get('users/u/reminders/a');db.put(j.path,{...j.data,anchorAtUtc:new Date(+now-1)});
 await run(db,()=>assert.fail('expired source sent'));assert.equal((await db.get(j.path)).data.status,'expired');
});
test('partial delivery persists successes, retries only failed devices with Retry-After',async()=>{
 const db=setup();db.put('users/u/devices/e',{enabled:true,token:'second-synthetic-token'});
 let calls=[];await run(db,async(_,o)=>{const t=JSON.parse(o.body).message.token;calls.push(t);return t.startsWith('second')?Response.json({error:{}},{status:503,headers:{'Retry-After':'90'}}):Response.json({name:'sent'});});
 const job=await db.get('users/u/reminders/a');assert.equal(job.data.status,'queued');assert.equal(+job.data.availableAtUtc,+now+90000);
 db.put(job.path,{...job.data,availableAtUtc:now});calls=[];
 await run(db,async(_,o)=>{calls.push(JSON.parse(o.body).message.token);return Response.json({name:'sent'});});
 assert.deepEqual(calls,['second-synthetic-token']);assert.equal((await db.get(job.path)).data.status,'sent');
});
test('invalid token disabled; old generation completion cannot overwrite a new generation',async()=>{
 const db=setup();await run(db,async()=>Response.json({error:{details:[{errorCode:'UNREGISTERED'}]}},{status:404}));
 assert.equal((await db.get('users/u/devices/d')).data.enabled,false);
 const other=setup();await run(other,async()=>{
  const j=await other.get('users/u/reminders/a');other.put(j.path,{...j.data,generation:2,status:'queued',leaseId:null});return Response.json({name:'sent'});
 });
 assert.equal((await other.get('users/u/reminders/a')).data.generation,2);
 assert.equal((await other.get('users/u/reminders/a')).data.status,'queued');assert.equal(await other.get('users/u/notifications/a_1'),null);
});
test('hard daily cap prevents sends and defers; no active devices fails explicitly',async()=>{
 const db=setup();db.put('usage/push_global_day_2026-10-21',{count:100});await run(db,()=>assert.fail('quota bypass'));
 assert.equal((await db.get('users/u/reminders/a')).data.lastError,'rate_limited');
 const other=setup();other.docs.delete('users/u/devices/d');await run(other,()=>assert.fail('no device'));
 assert.equal((await other.get('users/u/reminders/a')).data.lastError,'no_active_device');
});

test('permanent device errors are not retried when another device needs a retry',async()=>{
 const db=setup();db.put('users/u/devices/e',{enabled:true,token:'second-synthetic-token'});
 await run(db,async(_,o)=>JSON.parse(o.body).message.token.startsWith('second')?Response.json({error:{}},{status:503}):Response.json({error:{}},{status:400}));
 const j=await db.get('users/u/reminders/a');db.put(j.path,{...j.data,availableAtUtc:now});
 const calls=[];await run(db,async(_,o)=>{calls.push(JSON.parse(o.body).message.token);return Response.json({name:'sent'});});
 assert.deepEqual(calls,['second-synthetic-token']);
});
