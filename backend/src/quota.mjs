import {importPKCS8, SignJWT} from 'jose';
let oauth = null;
let oauthPending = null;
export async function googleAccess(env, fetcher = fetch) {
  const account = JSON.parse(env.GOOGLE_SERVICE_ACCOUNT ?? '{}');
  if (!account.client_email || !account.private_key || account.project_id !== env.FIREBASE_PROJECT_ID)
    throw new Error('backend_not_configured');
  const scope = env.GOOGLE_OAUTH_SCOPE ?? 'https://www.googleapis.com/auth/datastore';
  const identity = account.client_email + '|' + scope;
  if (oauth?.email === identity && oauth.until > Date.now()) return oauth.token;
  if (oauthPending?.email === identity) return oauthPending.promise;
  const promise = issueAccess(account,fetcher,scope);
  oauthPending = {email: identity,promise};
  try {return await promise;} finally {if (oauthPending?.promise === promise) oauthPending=null;}
}
async function issueAccess(account,fetcher,scope) {
  const key = await importPKCS8(account.private_key, 'RS256');
  const assertion = await new SignJWT({scope})
    .setProtectedHeader({alg: 'RS256'}).setIssuer(account.client_email).setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt().setExpirationTime('1h').sign(key);
  const response = await fetcher('https://oauth2.googleapis.com/token', {method: 'POST', redirect: 'manual', signal: AbortSignal.timeout(10000),
    body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion})});
  if (!response.ok) throw new Error('backend_unavailable');
  const result = await response.json();
  if (typeof result.access_token !== 'string') throw new Error('backend_unavailable');
  oauth = {email: account.client_email + '|' + scope, token: result.access_token, until: Date.now() + (Math.min(Number(result.expires_in) || 0,3600)-60)*1000};
  return oauth.token;
}

// Conditional atomic commits enforce all counters across Worker instances.
// Retry only when a document changed since batchGet; never retry the model.
export async function reserveQuota(identity, env, fetcher = fetch) {
  const limit = Number(env.AI_GLOBAL_DAILY_LIMIT);
  if (!Number.isInteger(limit) || limit < 1 || limit > 10000) throw new Error('backend_not_configured');
  const token = await googleAccess(env, fetcher);
  const base = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
  const now = new Date();
  const day = now.toISOString().slice(0,10), minute = now.toISOString().slice(0,16).replaceAll(':','-');
  const uid = encodeURIComponent(identity.uid);
  const buckets = [
    [`user_${uid}_minute_${minute}`,identity.anonymous ? 5 : 10],
    [`user_${uid}_day_${day}`,identity.anonymous ? 10 : 100],
    [`global_minute_${minute}`,10], [`global_day_${day}`,limit],
  ];
  async function api(method, body) {
    const res = await fetcher(`${base}:${method}`, {method: 'POST', redirect: 'manual', signal: AbortSignal.timeout(10000),
      headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'}, body: JSON.stringify(body)});
    if (!res.ok) {
      const status = (await res.json().catch(() => ({}))).error?.status;
      if (method === 'commit' && ['ABORTED','FAILED_PRECONDITION','ALREADY_EXISTS','NOT_FOUND'].includes(status)) throw new Error('quota_conflict');
      throw new Error('backend_unavailable');
    }
    return res.json();
  }
  const docs = buckets.map(([id]) => `${base.slice('https://firestore.googleapis.com/v1/'.length)}/usage/${id}`);
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const read = await api('batchGet', {documents: docs});
      if (!Array.isArray(read)) throw new Error('backend_unavailable');
      const writes = docs.map((name,i) => {
        const matches = read.filter(x => x.found?.name === name || x.missing === name);
        if (matches.length !== 1) throw new Error('backend_unavailable');
        const found = matches[0].found;
        const value = found ? Number(found.fields?.count?.integerValue) : 0;
        if (!Number.isSafeInteger(value) || value < 0 || (found && typeof found.updateTime !== 'string')) throw new Error('backend_unavailable');
        if (value >= buckets[i][1]) throw new Error('rate_limited');
        return {update: {name, fields: {count: {integerValue: String(value+1)}}},
          currentDocument: found ? {updateTime: found.updateTime} : {exists: false}};
      });
      await api('commit', {writes});
      return;
    } catch (error) {
      if (error.message !== 'quota_conflict' || attempt === 2) throw error;
    }
  }
}
