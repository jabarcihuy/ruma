// One cloud request, with a disposable anonymous UID's daily counter already full.
import {readFile,writeFile} from 'node:fs/promises';
import {googleAccess} from '../src/quota.mjs';
const root=new URL('../../',import.meta.url);
const config=JSON.parse(await readFile(new URL('config/firebase/google-services.json',root),'utf8'));
const apiKey=config.client.find(x=>x.client_info?.android_client_info?.package_name==='id.ruma.app').api_key[0].current_key;
const auth=(method,body)=>fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${apiKey}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
const report={date:'2026-10-19',scope:'Deployed quota rejection using an explicitly full disposable UID counter; global counter never reset',passed:false};
let session,seedPath,token;
const base='https://firestore.googleapis.com/v1/projects/mobile-app-3479f/databases/(default)/documents';
try {
 const s=await auth('signUp',{returnSecureToken:true});session=await s.json();if(!s.ok)throw Error('test_auth_failed');
 token=await googleAccess({FIREBASE_PROJECT_ID:'mobile-app-3479f',GOOGLE_SERVICE_ACCOUNT:await readFile(new URL('.local/service-account-ruma-proxy.json',root),'utf8')});
 const headers={Authorization:`Bearer ${token}`,'Content-Type':'application/json'};
 const day=new Date().toISOString().slice(0,10);
 seedPath=`${base}/usage/user_${encodeURIComponent(session.localId)}_day_${day}`;
 const count=async()=>{const r=await fetch(`${base}/usage/global_day_${day}`,{headers});const v=await r.json();return Number(v.fields?.count?.integerValue??0);};
 report.globalCountBefore=await count();
 const seed=await fetch(`${base}:commit`,{method:'POST',headers,body:JSON.stringify({writes:[{update:{name:seedPath.slice('https://firestore.googleapis.com/v1/'.length),fields:{count:{integerValue:'10'}}},currentDocument:{exists:false}}]})});
 if(!seed.ok)throw Error('quota_seed_failed');
 const requestId=`ruma-cloud-quota-${Date.now()}`;report.requestId=requestId;
 const response=await fetch('https://ruma-api.abduljabarbrngkl.workers.dev/v1/agent/turn',{method:'POST',headers:{'Content-Type':'application/json','User-Agent':'Ruma-Integration-Check/1',Authorization:`Bearer ${session.idToken}`},body:JSON.stringify({requestId,conversationId:'quota-check',turnId:'quota',timezone:'Asia/Jakarta',clientNow:new Date().toISOString(),messages:[{role:'user',content:'Tadi makan 18 ribu.'}]}),signal:AbortSignal.timeout(65000)});
 report.status=response.status;report.response=await response.json();report.globalCountAfter=await count();
 report.passed=response.status===429&&report.response.error==='rate_limited'&&report.globalCountBefore===report.globalCountAfter;
 report.providerCallBlocked=report.passed;
} catch(e){report.error=e.message.replaceAll(apiKey,'[REDACTED]');}
finally {
 if(seedPath&&token)report.syntheticCounterDeleted=(await fetch(seedPath,{method:'DELETE',headers:{Authorization:`Bearer ${token}`}})).ok;
 if(session?.idToken)report.testAccountDeleted=(await auth('delete',{idToken:session.idToken})).ok;
 await writeFile(new URL('docs/qa/cloud-quota-check.json',root),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
}
process.exitCode=report.passed?0:1;
