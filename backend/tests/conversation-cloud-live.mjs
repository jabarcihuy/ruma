// Explicit production smoke: one disposable UID, three model calls, no ledger writes.
import {readFile,writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
if(process.env.RUMA_LIVE_ASSISTANT_V2!=='mobile-app-3479f')throw Error('explicit_live_test_flag_required');
const directory=resolve(process.env.RUMA_QA_DIR??'');
if(!directory.startsWith(resolve('../.local')+'/'))throw Error('private_test_directory_required');
const config=JSON.parse(await readFile('../config/firebase/google-services.json','utf8'));
const key=config.client.find(c=>c.client_info?.android_client_info?.package_name==='id.ruma.app').api_key[0].current_key;
const base='https://ruma-api.abduljabarbrngkl.workers.dev';
const report={date:new Date().toISOString(),endpoint:base,project:'mobile-app-3479f',synthetic:true,ledgerWrites:0,modelCallsAttempted:0,cases:[]};
let session;
const save=()=>writeFile(directory+'/worker-cloud-results.json',JSON.stringify(report,null,2)+'\n');
async function auth(method,body){const r=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${key}`,{method:'POST',redirect:'manual',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(20000)});if(!r.ok)throw Error('auth_'+r.status);return r.json();}
function input(messages){const id='ruma-v2-cloud-'+Date.now();return {requestId:id,conversationId:'synthetic-cloud',turnId:id,timezone:'Asia/Jakarta',clientNow:new Date().toISOString(),messages};}
async function call(path,body,{model=true,multipart=false,token=session?.idToken}={}){
 if(model&&++report.modelCallsAttempted>3)throw Error('model_call_budget_exceeded');
 await save();const start=performance.now();
 const r=await fetch(base+path,{method:'POST',redirect:'manual',headers:{...(token?{Authorization:'Bearer '+token}:{}),...(!multipart?{'Content-Type':'application/json'}:{})},body:multipart?body:JSON.stringify(body),signal:AbortSignal.timeout(65000)});
 const result=await r.json();report.cases.push({path,status:r.status,wallMs:Math.round(performance.now()-start),response:result});await save();console.log(JSON.stringify({path,status:r.status,type:result.type,error:result.error}));return {status:r.status,body:result};
}
try {
 for(const path of ['/v1/agent/turn','/v2/agent/turn','/v2/agent/schedule','/v2/agent/schedule/correct']){
  const r=await call(path,{}, {model:false,token:null});assert.equal(r.status,401);
 }
 const forged=await call('/v2/agent/turn',input([{role:'user',content:'Halo'}]),{model:false,token:'invalid-token'});assert.equal(forged.status,401);
 session=await auth('signUp',{returnSecureToken:true});report.fixtureUid=session.localId;await save();
 const next=new Date(Date.now()+25200000+86400000).toISOString().slice(0,10);
 const followup=await call('/v2/agent/turn',input([{role:'user',content:`Pada ${next}, belajar basis data satu jam.`},{role:'assistant',content:'Mau belajar jam berapa?'},{role:'user',content:'Jam 10 aja.'}]));
 assert.equal(followup.status,200);assert.equal(followup.body.type,'draft_proposal');assert.equal(followup.body.items.length,1);assert.equal(followup.body.items[0].startLocal,next+'T10:00');assert.equal(followup.body.items[0].durationMinutes,60);
 const form=new FormData();form.append('images',new Blob([await readFile('../docs/qa/assistant-chat-import/synthetic-schedule.png')],{type:'image/png'}),'synthetic-schedule.png');
 const vision=await call('/v2/agent/schedule',form,{multipart:true});assert.equal(vision.status,200);assert.equal(vision.body.type,'schedule_extraction');assert.equal(vision.body.rows.length,4);
 const expected=[['Algoritma',1,'08:00','09:40'],['Basis Data',2,'10:00','11:40'],['Interaksi Manusia Komputer',4,'08:00','09:40'],['Pemrograman Berorientasi Objek',5,'13:00','14:40']];
 for(const [title,day,start,end] of expected){const row=vision.body.rows.find(r=>r.title?.toLowerCase()===title.toLowerCase());assert.ok(row,title);assert.equal(row.weekday,day);assert.equal(row.start,start);assert.equal(row.end,end);}
 const rows=vision.body.rows.map((r,index)=>({index,title:r.title,weekday:r.weekday,date:null,start:r.start,end:r.end,location:r.location??'',included:true}));
 const corrected=await call('/v2/agent/schedule/correct',{...input([{role:'user',content:'Basis Data pindah ke Kamis, tetap jam 10.'}]),rows});
 assert.equal(corrected.status,200);assert.equal(corrected.body.type,'schedule_correction');assert.equal(corrected.body.question,'');assert.equal(corrected.body.updates.length,1);const update=corrected.body.updates[0];assert.equal(update.index,rows.findIndex(r=>r.title.toLowerCase()==='basis data'));assert.equal(update.weekday,4);assert.equal(update.start,'10:00');
 report.passed=true;
}catch(e){report.passed=false;report.error=e.name==='AssertionError'?e.message:e.message.replaceAll(key,'[redacted]');}
finally{if(session)try{await auth('delete',{idToken:session.idToken});report.authFixtureDeleted=true;}catch{report.authFixtureDeleted=false;}await save();console.log(JSON.stringify({passed:report.passed,modelCallsAttempted:report.modelCallsAttempted,authFixtureDeleted:report.authFixtureDeleted}));}
process.exitCode=report.passed?0:1;
