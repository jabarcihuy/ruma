import {decodeProtectedHeader, importJWK, jwtVerify} from 'jose';
const CERTS = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
let certificates = {}, expires = 0, refreshed = 0;
const imported = new Map();

export async function verifyFirebase(token, projectId, fetcher = fetch) {
  if (typeof token !== 'string' || token.length > 8192) throw new Error('unauthenticated');
  try {
    const {alg, kid} = decodeProtectedHeader(token);
    if (alg !== 'RS256' || typeof kid !== 'string' || kid.length > 128) throw new Error();
    const now = Date.now();
    if (now >= expires || (!certificates[kid] && now - refreshed > 30000)) {
      const response = await fetcher(CERTS, {redirect: 'manual', signal: AbortSignal.timeout(10000)});
      if (!response.ok) throw new Error();
      const text = await response.text();
      if (text.length > 128000) throw new Error();
      const value = JSON.parse(text);
      if (!Array.isArray(value?.keys) || !value.keys.length || value.keys.length > 20
        || value.keys.some(key => !key || key.kty !== 'RSA' || key.alg !== 'RS256' || key.use !== 'sig'
          || typeof key.kid !== 'string' || typeof key.n !== 'string' || typeof key.e !== 'string' || 'd' in key)
        || new Set(value.keys.map(key => key.kid)).size !== value.keys.length) throw new Error();
      certificates = Object.fromEntries(value.keys.map(key => [key.kid, key]));
      imported.clear();
      refreshed = now;
      const age = Number(response.headers.get('cache-control')?.match(/max-age=(\d+)/)?.[1] ?? 60);
      expires = now + Math.min(age, 21600) * 1000;
    }
    if (!Object.hasOwn(certificates, kid)) throw new Error();
    if (!imported.has(kid)) imported.set(kid, await importJWK(certificates[kid], 'RS256'));
    const {payload} = await jwtVerify(token, imported.get(kid), {
      algorithms: ['RS256'], audience: projectId, issuer: `https://securetoken.google.com/${projectId}`,
      requiredClaims: ['exp', 'iat', 'auth_time', 'sub'],
    });
    const seconds = Math.floor(Date.now()/1000);
    if (typeof payload.sub !== 'string' || !payload.sub || payload.sub.length > 128 || !Number.isInteger(payload.iat) || payload.iat > seconds
      || !Number.isInteger(payload.auth_time) || payload.auth_time > seconds || payload.auth_time > payload.iat
      || !Number.isInteger(payload.exp) || payload.exp <= payload.iat) throw new Error();
    return {uid: payload.sub, anonymous: payload.firebase?.sign_in_provider === 'anonymous'};
  } catch { throw new Error('unauthenticated'); }
}
