// Deletes only the synthetic UID named by this exact approved Android test run.
import {readFile,writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {googleAccess} from '../src/quota.mjs';
if(process.env.RUMA_CLEAN_SCHEDULE_FIXTURE!=='mobile-app-3479f')throw Error('explicit_cleanup_flag_required');
const directory=resolve(process.env.RUMA_QA_DIR??'');
if(!directory.startsWith(resolve('../.local')+'/'))throw Error('private_test_directory_required');
const manifest=JSON.parse(await readFile(directory+'/schedule-import-cloud-results.json','utf8'));
const uid=manifest.fixtureUid;
if(manifest.project!=='mobile-app-3479f'||manifest.suite!=='schedule_import_cloud_test'
  ||!Array.isArray(manifest.authFixturesDeleted)||!manifest.authFixturesDeleted.includes(uid)
  ||typeof uid!=='string'||!/^[A-Za-z0-9_-]{20,128}$/.test(uid))throw Error('unexpected_fixture_manifest');
const token=await googleAccess({FIREBASE_PROJECT_ID:manifest.project,GOOGLE_SERVICE_ACCOUNT:await readFile('../.local/service-account-ruma-proxy.json','utf8')});
const base='https://firestore.googleapis.com/v1/projects/mobile-app-3479f/databases/(default)/documents';
const headers={Authorization:`Bearer ${token}`},deleted=[];
for(const collection of ['agenda','state','operations','assistant','settings','devices','reminders','notifications']) {
  const path=`${base}/users/${uid}/${collection}`;
  const list=await fetch(path+'?pageSize=30',{headers,signal:AbortSignal.timeout(15000)});
  if(!list.ok)throw Error('fixture_list_'+list.status);
  const data=await list.json();if(data.nextPageToken||(data.documents?.length??0)>20)throw Error('fixture_scope_exceeded');
  for(const document of data.documents??[]) {
    if(!document.name.startsWith(`projects/mobile-app-3479f/databases/(default)/documents/users/${uid}/${collection}/`))throw Error('path_mismatch');
    const response=await fetch('https://firestore.googleapis.com/v1/'+document.name,{method:'DELETE',headers,signal:AbortSignal.timeout(15000)});
    if(!response.ok)throw Error('fixture_delete_'+response.status);
    deleted.push(document.name.split('/documents/')[1]);
  }
  const verify=await fetch(path+'?pageSize=1',{headers,signal:AbortSignal.timeout(15000)});
  if(!verify.ok||((await verify.json()).documents?.length??0)>0)throw Error('fixture_not_empty');
}
await writeFile(directory+'/schedule-import-cloud-cleanup.json',JSON.stringify({project:manifest.project,fixtureUid:uid,deleted,verifiedEmpty:true,otherUserDataTouched:false},null,2)+'\n');
console.log(JSON.stringify({verifiedEmpty:true,documentsDeleted:deleted.length,otherUserDataTouched:false}));
