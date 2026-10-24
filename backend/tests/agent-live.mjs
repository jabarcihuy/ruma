// Opt-in live check: five synthetic model requests maximum, no retries or writes.
import {readFile, writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {MODEL, ENDPOINT, DRAFT_TOOL, systemPrompt, normalizeDraft} from '../src/agent.mjs';
const root = new URL('../../', import.meta.url);
const secret = await readFile(new URL('.local/ai.env', root), 'utf8');
const key = secret.split('\n').find(x => x.startsWith('NARAROUTER_API_KEY='))?.split('=').slice(1).join('=').trim().replace(/^["']|["']$/g, '');
assert.match(key ?? '', /^sk-nry-\S+$/);
const bounded = process.argv.includes('--bounded');
const reportPath = bounded ? 'docs/qa/agent-output-limit-check.json' : 'docs/qa/agent-policy-check.json';
const report = {date: '2026-10-19', model: MODEL, maxTokens: bounded ? 8192 : null, scope: 'Direct synthetic provider + shared output guard; not full app/Worker', databaseWrites: 0, modelRequests: 0, cases: []};
const cases = [
  {text: 'Besok mau beli buku 50 ribu.', expected: 'clarification'},
  {text: 'Besok mau beli buku 50 ribu.', expected: 'clarification'},
  {text: 'Mau beli buku 50 ribu, tapi uangnya belum keluar.', expected: 'clarification'},
  {text: 'Besok revisi laporan satu jam dan baca jurnal 30 menit. Tadi makan 18 ribu dan cetak laporan 15 ribu.', expected: 'draft_proposal', combined: true},
  {text: 'Tadi beli buku 50 ribu.', expected: 'draft_proposal', actual: true},
];
const selectedCases = bounded ? cases.filter(x => x.combined) : cases;
for (const sample of selectedCases) {
  const entry = {input: sample.text, expected: sample.expected, passed: false};
  report.cases.push(entry);
  const started = performance.now();
  try {
    report.modelRequests++;
    const response = await fetch(ENDPOINT, {method: 'POST', redirect: 'error', signal: AbortSignal.timeout(45000),
      headers: {Authorization: `Bearer ${key}`, 'Content-Type': 'application/json'},
      body: JSON.stringify({model: MODEL, messages: [{role: 'system', content: systemPrompt('2026-10-18')}, {role: 'user', content: sample.text}], tools: [DRAFT_TOOL], ...(bounded ? {max_tokens:8192} : {})})});
    entry.httpStatus = response.status;
    assert.equal(response.status, 200);
    const data = await response.json();
    const msg = data.choices?.[0]?.message;
    entry.responseModel = data.model;
    entry.finishReason = data.choices?.[0]?.finish_reason;
    entry.usage = data.usage;
    assert.equal(data.model, MODEL);
    entry.modelToolCalled = Boolean(msg?.tool_calls?.length);
    entry.modelText = typeof msg?.content === 'string' ? msg.content.slice(0, 1000) : null;
    const result = normalizeDraft(msg, sample.text, '2026-10-18');
    entry.result = result;
    assert.equal(result.type, sample.expected);
    if (sample.combined) {
      const agenda = result.items.filter(x => x.action === 'create_agenda');
      const expenses = result.items.filter(x => x.action === 'create_transaction');
      assert.deepEqual(agenda.map(x => x.durationMinutes).sort((a,b) => a-b), [30, 60]);
      assert.ok(agenda.every(x => x.localDate === '2026-10-19'));
      assert.deepEqual(expenses.map(x => [x.amountRupiah,x.categoryId]).sort((a,b) => a[0]-b[0]), [[15000,'other'],[18000,'food']]);
      assert.ok(expenses.every(x => x.localDate === '2026-10-18'));
    }
    if (sample.actual) assert.equal(result.items[0]?.amountRupiah, 50000);
    entry.passed = true;
  } catch (error) {
    entry.error = error.name === 'AssertionError' ? 'Unexpected normalized result or fixture values' : error.message;
  }
  entry.latencyMs = Math.round(performance.now()-started);
  report.overallPassed = report.cases.length === selectedCases.length && report.cases.every(x => x.passed);
  const safe = JSON.stringify(report, null, 2).replaceAll(key, '[REDACTED]').replace(/sk-nry-[\w-]+/g, '[REDACTED]');
  await writeFile(new URL(reportPath, root), safe+'\n');
  console.log(JSON.stringify({case: report.cases.length, passed: entry.passed, latencyMs: entry.latencyMs}));
}
process.exitCode = report.overallPassed ? 0 : 1;
