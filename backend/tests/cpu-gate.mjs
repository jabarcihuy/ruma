// Reproducible check of measured invocation CPU, never client wall time.
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const report=JSON.parse(await readFile(new URL('../../docs/qa/cloud-cpu-check.json',import.meta.url),'utf8'));
const section=process.argv[2]??'afterProductionBuild';
const samples=report[section];
assert.ok(Array.isArray(samples)&&samples.length>=2,`Missing measured section: ${section}`);
assert.ok(samples.every(x=>x.status===200&&Number.isFinite(x.cpuTimeMs)&&x.cpuTimeMs>=0),'Incomplete successful invocation evidence');
console.log(JSON.stringify({section,cpuTimeMs:samples.map(x=>x.cpuTimeMs),limitMs:report.nominalFreeRequestCpuMs}));
assert.ok(samples.every(x=>x.cpuTimeMs<=report.nominalFreeRequestCpuMs),'Measured invocation exceeds nominal Free CPU limit');
console.log('PASS: measured samples only; not a worst-case guarantee.');
