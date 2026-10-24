// Explicit cloud test: temporary anonymous account, two model requests maximum.
import {readFile,writeFile,unlink} from 'node:fs/promises';
import assert from 'node:assert/strict';
const root=new URL('../../',import.meta.url);
const config=JSON.parse(await readFile(new URL('config/firebase/google-services.json',root),'utf8'));
const client=config.client.find(x=>x.client_info?.android_client_info?.package_name==='id.ruma.app');
const key=client.api_key[0].current_key;
const endpoint='https://ruma-api.abduljabarbrngkl.workers.dev/v1/agent/turn';
const report={date:'2026-10-19',endpoint,scope:'Actual deployed Worker, Firebase anonymous JWT and Firestore quota; synthetic data only',ledgerWrites:0,requests:[],modelRequestsAttempted:0};
let session;
async function auth(method,body) {
 const r=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${key}`,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
 const value=await r.json();if(!r.ok) throw new Error(`auth_${r.status}`);return value;
}
async function save() {await writeFile(new URL('docs/qa/cloud-proxy-check.json',root),JSON.stringify(report,null,2)+'\n');}
async function turn(name,token,text) {
 const requestId=`ruma-cloud-${name}-${Date.now()}`;
 const data={requestId,conversationId:'synthetic-cloud',turnId:name,timezone:'Asia/Jakarta',clientNow:new Date().toISOString(),messages:[{role:'user',content:text}]};
 const start=performance.now();
 const r=await fetch(endpoint,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json','User-Agent':'Ruma-Integration-Check/1',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(data),signal:AbortSignal.timeout(65000)});
 const raw=await r.text();let body;try{body=JSON.parse(raw);}catch{body={nonJsonResponse:true};}
 const entry={name,requestId,status:r.status,wallTimeMs:Math.round(performance.now()-start),response:body};
 report.requests.push(entry);await save();console.log(JSON.stringify({name,status:r.status,type:body.type,error:body.error,wallTimeMs:entry.wallTimeMs}));return entry;
}
try {
 for(const [name,token] of [['no-auth',null],['forged-auth','invalid-token']]) {
  const result=await turn(name,token,'Tadi makan 18 ribu.');assert.equal(result.status,401);
 }
 session=await auth('signUp',{returnSecureToken:true});
 report.testAccountCreated=true;
 await writeFile(new URL('.local/cloud-test-session.json',root),JSON.stringify({idToken:session.idToken,localId:session.localId}),{mode:0o600});
 for(const [name,text] of [['first-authenticated','Besok revisi laporan satu jam dan baca jurnal 30 menit. Tadi makan 18 ribu dan cetak laporan 15 ribu.'],['repeat-authenticated','Besok mau beli buku 50 ribu.']]) {
  report.modelRequestsAttempted++;
  const result=await turn(name,session.idToken,text);
  assert.equal(result.status,200);
  assert.equal(result.response.type,name==='first-authenticated'?'draft_proposal':'clarification');
  if(name==='first-authenticated') {
   const items=result.response.items;assert.equal(items.length,4);
   assert.deepEqual(items.filter(x=>x.action==='create_transaction').map(x=>x.amountRupiah).sort((a,b)=>a-b),[15000,18000]);
   assert.deepEqual(items.filter(x=>x.action==='create_agenda').map(x=>x.durationMinutes).sort((a,b)=>a-b),[30,60]);
  }
 }
 report.passed=true;
} catch(e){report.passed=false;report.error=e.name==='AssertionError'?'Unexpected cloud response':e.message.replaceAll(key,'[REDACTED]');}
finally {
 if(session) try{await auth('delete',{idToken:session.idToken});report.testAccountDeleted=true;await unlink(new URL('.local/cloud-test-session.json',root));}catch{report.testAccountDeleted=false;}
 await save();console.log(JSON.stringify({passed:report.passed,accountDeleted:report.testAccountDeleted}));
}
process.exitCode=report.passed?0:1;
