import {dispatchReminders} from './notifications.mjs';
import {verifyFirebase} from './auth.mjs';
import {reserveQuota} from './quota.mjs';
import {MODEL, ENDPOINT, AGENT_TOOLS, systemPrompt, normalizeDraft, clarification} from './agent.mjs';

const json = (value,status=200) => Response.json(value, {status, headers: {'Cache-Control': 'no-store'}});
const keys = ['requestId','conversationId','turnId','timezone','clientNow','messages'];
async function boundedText(stream,limit) {
  const reader=stream?.getReader();
  if (!reader) throw new Error('invalid_request');
  const chunks=[];let bytes=0;
  while (true) {
    const {done,value}=await reader.read();
    if (done) break;
    bytes+=value.byteLength;
    if (bytes>limit) {await reader.cancel();throw new Error('payload_limit');}
    chunks.push(value);
  }
  return new TextDecoder().decode(await new Blob(chunks).arrayBuffer());
}
export function validateRequest(value, now = Date.now()) {
  if (!value || Array.isArray(value) || typeof value !== 'object' || Object.keys(value).some(k => !keys.includes(k))) throw new Error('invalid_request');
  if (!['requestId','conversationId','turnId'].every(k => typeof value[k] === 'string' && /^[a-zA-Z0-9_-]{1,80}$/.test(value[k]))
    || value.timezone !== 'Asia/Jakarta' || !Number.isFinite(Date.parse(value.clientNow))
    || Math.abs(Date.parse(value.clientNow)-now) > 300000
    || !Array.isArray(value.messages) || value.messages.length !== 1
    || value.messages[0]?.role !== 'user' || typeof value.messages[0].content !== 'string'
    || !value.messages[0].content.trim() || value.messages[0].content.length > 4000
    || Object.keys(value.messages[0]).some(k => !['role','content'].includes(k))) throw new Error('invalid_request');
  return value;
}

// One bounded model call routes reads/proposals; only the authenticated app executes them.
export async function handle(request, env, services = {}) {
  const url = new URL(request.url);
  if (url.pathname !== '/v1/agent/turn') return json({error: 'not_found'},404);
  if (request.method !== 'POST') return json({error: 'method_not_allowed'},405);
  let requestId;
  try {
    const bearer = request.headers.get('Authorization')?.match(/^Bearer (\S+)$/)?.[1];
    if (!bearer) throw new Error('unauthenticated');
    const identity = await (services.verify ?? verifyFirebase)(bearer, env.FIREBASE_PROJECT_ID);
    if (!request.headers.get('Content-Type')?.startsWith('application/json')) throw new Error('invalid_request');
    if (Number(request.headers.get('Content-Length')) > 65536) throw new Error('invalid_request');
    let body;
    try { body = JSON.parse(await boundedText(request.body,65536)); }
    catch { throw new Error('invalid_request'); }
    const input = validateRequest(body);
    requestId = input.requestId;
    if (!env.NARAROUTER_API_KEY) throw new Error('backend_not_configured');
    await (services.quota ?? reserveQuota)(identity, env);
    // ponytail: requests currently accept Jakarta only (UTC+7, no DST).
    // Use a cached IANA formatter when the integration accepts other time zones.
    const localDate = new Date(Date.now() + 25200000).toISOString().slice(0,10);
    const response = await (services.fetch ?? fetch)(ENDPOINT, {
      method: 'POST', redirect: 'manual', signal: AbortSignal.any([request.signal,AbortSignal.timeout(45000)]),
      headers: {Authorization: `Bearer ${env.NARAROUTER_API_KEY}`, 'Content-Type': 'application/json'},
      body: JSON.stringify({model: MODEL, messages: [{role: 'system',content: systemPrompt(localDate)}, ...input.messages], tools: AGENT_TOOLS,max_tokens:8192}),
    });
    if (!response.ok) throw new Error(response.status === 429 ? 'provider_rate_limited' : 'provider_unavailable');
    // Bounded response reader avoids returning huge reasoning payloads to the app.
    let text;
    try {text=await boundedText(response.body,1000000);}
    catch(error) {if (error.message==='payload_limit') throw new Error('invalid_model_output');throw error;}
    let result;
    try { result = JSON.parse(text); } catch { throw new Error('invalid_model_output'); }
    if (result.model !== MODEL || !['stop','tool_calls'].includes(result.choices?.[0]?.finish_reason)) throw new Error('invalid_model_output');
    return json({requestId, ...normalizeDraft(result.choices?.[0]?.message,input.messages[0].content,localDate)});
  } catch (error) {
    const code = error.name === 'TimeoutError' ? 'provider_timeout' : error.name === 'AbortError' ? 'request_cancelled' : error.message;
    if (code === 'invalid_model_output') return json({requestId, ...clarification('incomplete_draft')});
    const statuses = {unauthenticated:401, invalid_request:400, rate_limited:429, provider_rate_limited:429,
      provider_timeout:504, provider_unavailable:502, invalid_model_output:502, tool_limit:422,
      backend_not_configured:503, backend_unavailable:503, quota_conflict:503, request_cancelled:408};
    return json({requestId,error: Object.hasOwn(statuses,code) ? code : 'backend_unavailable'}, statuses[code] ?? 503);
  }
}
export default {fetch: (request,env) => handle(request,env), scheduled: (_event,env,ctx) => ctx.waitUntil(dispatchReminders(env).then(result=>console.log(JSON.stringify({reminders:result}))))};
