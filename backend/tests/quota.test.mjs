import {test} from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPair,exportPKCS8} from 'jose';
import {writeFile} from 'node:fs/promises';
import {reserveQuota} from '../src/quota.mjs';
test('conditional atomic quota commit limits concurrent reservations',async()=>{
  const host=process.env.FIRESTORE_EMULATOR_HOST;
  assert.match(host??'',/^127\.0\.0\.1:\d+$/);
  const {privateKey}=await generateKeyPair('RS256',{extractable:true});
  const env={FIREBASE_PROJECT_ID:'demo-ruma',AI_GLOBAL_DAILY_LIMIT:'3',GOOGLE_SERVICE_ACCOUNT:JSON.stringify({project_id:'demo-ruma',client_email:'synthetic@demo-ruma.iam.gserviceaccount.com',private_key:await exportPKCS8(privateKey)})};
  const instant=new Date().toISOString(),day=instant.slice(0,10),minute=instant.slice(0,16).replaceAll(':','-');
  for (const id of [`global_day_${day}`,`global_minute_${minute}`,`user_quota-synthetic_day_${day}`,`user_quota-synthetic_minute_${minute}`])
    await fetch(`http://${host}/v1/projects/demo-ruma/databases/(default)/documents/usage/${id}`,{method:'DELETE',headers:{Authorization:'Bearer owner'}});
  let oauthCalls=0;
  const fetcher=async(url,options)=>{
    if (url==='https://oauth2.googleapis.com/token') {oauthCalls++;return Response.json({access_token:'synthetic-emulator-only',expires_in:3600});}
    assert.equal(new URL(url).hostname,'firestore.googleapis.com');
    assert.ok(new URL(url).pathname.includes('/projects/demo-ruma/'));
    return fetch(`http://${host}${new URL(url).pathname}`,{...options,headers:{...options.headers,Authorization:'Bearer owner'}});
  };
  const results=await Promise.allSettled(Array.from({length:8},()=>reserveQuota({uid:'quota-synthetic',anonymous:true},env,fetcher)));
  const succeeded=results.filter(x=>x.status==='fulfilled').length;
  const failed=results.filter(x=>x.status==='rejected').map(x=>x.reason.message);
  const now=new Date().toISOString().slice(0,10);
  const response=await fetch(`http://${host}/v1/projects/demo-ruma/databases/(default)/documents/usage/global_day_${now}`,{headers:{Authorization:'Bearer owner'}});
  const document=await response.json();
  const count=Number(document.fields?.count?.integerValue);
  const report={date:'2026-10-19',scope:'Firestore REST emulator conditional atomic commits; OAuth mocked with ephemeral synthetic key',productionWrites:0,concurrentReservations:8,globalDailyLimit:3,succeeded,rejected:failed.length,errors:failed,persistedCount:count,oauthRequests:oauthCalls,passed:succeeded===3&&count===3};
  await writeFile(new URL('../../docs/qa/quota-concurrency-check.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
  assert.equal(succeeded,3);assert.equal(count,3);
  assert.equal(oauthCalls,1);
  assert.ok(failed.every(x=>['rate_limited','quota_conflict'].includes(x)));
  await assert.rejects(()=>reserveQuota({uid:'quota-synthetic',anonymous:true},env,fetcher),/rate_limited/);
});
