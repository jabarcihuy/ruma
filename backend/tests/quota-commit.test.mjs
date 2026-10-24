import {test} from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPair,exportPKCS8} from 'jose';
import {reserveQuota} from '../src/quota.mjs';
test('quota uses two calls, conditional atomic commit and bounded conflict retry',async()=>{
 const {privateKey}=await generateKeyPair('RS256',{extractable:true});
 const env={FIREBASE_PROJECT_ID:'demo-ruma',AI_GLOBAL_DAILY_LIMIT:'10',GOOGLE_SERVICE_ACCOUNT:JSON.stringify({project_id:'demo-ruma',client_email:'cas-test@demo-ruma.iam.gserviceaccount.com',private_key:await exportPKCS8(privateKey)})};
 let calls=[],reads=0,commits=0,full=false;
 const fetcher=async(url,options)=>{
  if(url==='https://oauth2.googleapis.com/token')return Response.json({access_token:'synthetic',expires_in:3600});
  const method=url.split(':').at(-1),body=JSON.parse(options.body);calls.push(method);
  if(method==='batchGet'){
   reads++;
   return Response.json(body.documents.map((name,i)=>reads===1?{missing:name}:{found:{name,fields:{count:{integerValue:full?'10':'1'}},updateTime:'2026-10-19T00:00:00.000001Z'}}));
  }
  assert.equal(method,'commit');
  assert.equal(body.writes.length,4);
  for(const write of body.writes)assert.deepEqual(write.currentDocument,reads===1?{exists:false}:{updateTime:'2026-10-19T00:00:00.000001Z'});
  commits++;
  if(commits===1)return Response.json({error:{status:'FAILED_PRECONDITION'}},{status:400});
  return Response.json({writeResults:[{},{},{},{}]});
 };
 await reserveQuota({uid:'synthetic',anonymous:true},env,fetcher);
 assert.deepEqual(calls,['batchGet','commit','batchGet','commit']);
 full=true;calls=[];
 await assert.rejects(()=>reserveQuota({uid:'synthetic',anonymous:true},env,fetcher),/rate_limited/);
 assert.deepEqual(calls,['batchGet']);
});
