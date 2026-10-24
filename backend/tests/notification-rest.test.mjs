import {test} from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync} from 'node:crypto';
import {reminderDatabase} from '../src/reminder-db.mjs';
import {googleAccess} from '../src/quota.mjs';
test('Firestore adapter decodes timestamps and encodes conditional atomic writes',async()=>{
 const date='2026-10-21T00:00:00.123456Z',name='projects/demo-ruma/databases/(default)/documents/users/u/reminders/a';
 let calls=0;
 const db=reminderDatabase('demo-ruma','synthetic',async(url,o)=>{
  calls++;
  if(o.method==='GET')return Response.json({name,updateTime:date,fields:{generation:{integerValue:'2'},enabled:{booleanValue:true},anchorAtUtc:{timestampValue:date},leaseId:{nullValue:null},deviceResults:{mapValue:{fields:{device:{stringValue:'sent'}}}}}});
  if(url.endsWith(':commit')){
   const b=JSON.parse(o.body);assert.equal(b.writes[0].currentDocument.updateTime,date);
   assert.equal(b.writes[0].update.fields.anchorAtUtc.timestampValue,date);
   assert.equal(b.writes[0].update.fields.deviceResults.mapValue.fields.device.stringValue,'sent');return Response.json({});
  }
  assert.ok(url.endsWith('/users/u:runQuery'));return Response.json([]);
 });
 const doc=await db.get('users/u/reminders/a');assert.equal(doc.data.generation,2);assert.equal(doc.data.enabled,true);
 await db.commit([doc]);await db.query('users/u',{limit:3});assert.equal(calls,3);
 const fail=reminderDatabase('demo-ruma','synthetic',async()=>Response.json({error:{}},{status:409}));
 await assert.rejects(fail.commit([doc]),/conflict/);
});
test('OAuth cache never mixes datastore and FCM scopes',async()=>{
 const {privateKey}=generateKeyPairSync('rsa',{modulusLength:2048});
 const env={FIREBASE_PROJECT_ID:'demo-ruma',GOOGLE_SERVICE_ACCOUNT:JSON.stringify({project_id:'demo-ruma',client_email:'synthetic@example.invalid',private_key:privateKey.export({type:'pkcs8',format:'pem'})})};
 const scopes=[];
 const fetcher=async(_url,o)=>{const payload=JSON.parse(Buffer.from(o.body.get('assertion').split('.')[1],'base64url'));scopes.push(payload.scope);return Response.json({access_token:'synthetic-'+scopes.length,expires_in:3600});};
 assert.equal(await googleAccess(env,fetcher),'synthetic-1');
 assert.equal(await googleAccess(env,fetcher),'synthetic-1');
 const push={...env,GOOGLE_OAUTH_SCOPE:'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging'};
 assert.equal(await googleAccess(push,fetcher),'synthetic-2');
 assert.equal(await googleAccess(push,fetcher),'synthetic-2');
 assert.ok(scopes[1].includes('firebase.messaging'));assert.ok(!scopes[0].includes('firebase.messaging'));
});
