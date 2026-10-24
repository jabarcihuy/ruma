// Real Firebase JWT in local workerd. No model calls or Firestore writes.
import {readFile,writeFile} from 'node:fs/promises';
const root=new URL('../../',import.meta.url);
const c=JSON.parse(await readFile(new URL('config/firebase/google-services.json',root),'utf8'));
const key=c.client.find(x=>x.client_info?.android_client_info?.package_name==='id.ruma.app').api_key[0].current_key;
const auth=(method,body)=>fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${key}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
const signup=await auth('signUp',{returnSecureToken:true}),session=await signup.json();
const report={date:'2026-10-19',signupStatus:signup.status,modelRequests:0};
if(signup.ok) try {
 const r=await fetch('http://127.0.0.1:8796/v1/agent/turn',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${session.idToken}`},body:'{}'});
 report.workerdStatus=r.status;report.response=await r.json();report.authPassed=r.status===400;
} catch(e){report.error=e.name;report.authPassed=false;}
finally {report.accountDeleted=(await auth('delete',{idToken:session.idToken})).ok;}
await writeFile(new URL('docs/qa/workerd-real-jwt-diagnostic.json',root),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));process.exitCode=report.authPassed?0:1;
