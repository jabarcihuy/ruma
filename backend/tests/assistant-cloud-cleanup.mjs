// Explicit one-run cleanup: only UIDs emitted by the authorized assistant Android smoke.
// Never scans users or touches usage or other accounts.
import {readFile, writeFile} from 'node:fs/promises';
import {googleAccess} from '../src/quota.mjs';
const root = new URL('../../', import.meta.url);
const finalSuite = process.env.RUMA_CLEAN_FINAL_STAGES_FIXTURES === 'mobile-app-3479f';
const memorySuite = process.env.RUMA_CLEAN_ASSISTANT_MEMORY_FIXTURES === 'mobile-app-3479f';
const notificationsSuite = process.env.RUMA_CLEAN_NOTIFICATION_FIXTURES === 'mobile-app-3479f';
const toolsSuite = process.env.RUMA_CLEAN_AGENT_TOOLS_FIXTURES === 'mobile-app-3479f';
if (!finalSuite && !memorySuite && !notificationsSuite && !toolsSuite && process.env.RUMA_CLEAN_ASSISTANT_FIXTURES !== 'mobile-app-3479f') throw Error('explicit_cleanup_flag_required');
const manifestFile = process.env.RUMA_ASSISTANT_FIXTURE_MANIFEST ?? 'cloud-results.json';
if (!(notificationsSuite ? ['cloud-results.json','terminated-results.json'] : ['cloud-results.json']).includes(manifestFile)) throw Error('unexpected_manifest_file');
const directory = finalSuite ? 'docs/qa/final-stages-1-3' : memorySuite ? 'docs/qa/assistant-memory' : notificationsSuite ? 'docs/qa/notifications' : toolsSuite ? 'docs/qa/agent-stages-1-3' : 'docs/qa/assistant';
const result = JSON.parse(await readFile(new URL(`${directory}/${manifestFile}`, root), 'utf8'));
if (result.project !== 'mobile-app-3479f' || result.suite !== (finalSuite ? 'final_stages_cloud_test' : memorySuite ? 'assistant_memory_cloud_test' : notificationsSuite ? 'notifications_cloud_test' : toolsSuite ? 'agent_tools_cloud_test' : 'assistant_cloud_test') || ![1,2].includes(result.fixtureUids?.length) ||
    !result.fixtureUids.every(uid => /^[A-Za-z0-9_-]{20,128}$/.test(uid) && result.authFixturesDeleted.includes(uid))) {
  throw Error('unexpected_fixture_manifest');
}
const token = await googleAccess({FIREBASE_PROJECT_ID: result.project,
  GOOGLE_SERVICE_ACCOUNT: await readFile(new URL('.local/service-account-ruma-proxy.json', root), 'utf8')});
const base = 'https://firestore.googleapis.com/v1/projects/mobile-app-3479f/databases/(default)/documents';
const headers = {Authorization: `Bearer ${token}`};
const report = {project: result.project, fixtureUids: result.fixtureUids, deleted: [], verifiedEmpty: false, modelCalls: 0};
for (const uid of result.fixtureUids) {
  for (const collection of (finalSuite ? ['agenda','transactions','months','state','operations','assistant','settings','devices','reminders','notifications'] : memorySuite ? ['agenda','transactions','months','state','operations','assistant'] : notificationsSuite ? ['agenda','state','operations','devices','reminders','notifications'] : ['agenda', 'transactions', 'months', 'state', 'operations'])) {
    const path = `${base}/users/${uid}/${collection}`;
    const list = await fetch(`${path}?pageSize=30`, {headers});
    if (!list.ok) throw Error(`fixture_list_${list.status}`);
    const data = await list.json();
    if (data.nextPageToken || (data.documents?.length ?? 0) > 20) throw Error('fixture_scope_exceeded');
    for (const doc of data.documents ?? []) {
      if (!doc.name.startsWith(`projects/mobile-app-3479f/databases/(default)/documents/users/${uid}/${collection}/`)) throw Error('path_mismatch');
      const deletion = await fetch(`https://firestore.googleapis.com/v1/${doc.name}`, {method: 'DELETE', headers});
      if (!deletion.ok) throw Error(`fixture_delete_${deletion.status}`);
      report.deleted.push(doc.name.split('/documents/')[1]);
    }
    const verify = await fetch(`${path}?pageSize=1`, {headers});
    if (!verify.ok || ((await verify.json()).documents?.length ?? 0) > 0) throw Error('fixture_not_empty');
  }
}
report.verifiedEmpty = true;
await writeFile(new URL(`${directory}/${manifestFile === 'terminated-results.json' ? 'terminated-cleanup.json' : 'cloud-cleanup.json'}`, root), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({verifiedEmpty: true, documentsDeleted: report.deleted.length, authAccountsDeleted: result.authFixturesDeleted.length}));
