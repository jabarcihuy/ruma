import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {X509Certificate} from 'node:crypto';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {importPKCS8,SignJWT,generateKeyPair,exportJWK} from 'jose';
import {verifyFirebase} from '../src/auth.mjs';
test('verify signature, expiry, project, subject and auth time; cache certificate', async () => {
  const directory=await mkdtemp(join(tmpdir(),'ruma-auth-test-'));
  try {
    execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=RumaSyntheticTest','-keyout',join(directory,'key.pem'),'-out',join(directory,'cert.pem')],{stdio:'ignore'});
    const key=await importPKCS8(await readFile(join(directory,'key.pem'),'utf8'),'RS256');
    const certificate=await readFile(join(directory,'cert.pem'),'utf8');
    let calls=0;
    const jwk={...new X509Certificate(certificate).publicKey.export({format:'jwk'}),kid:'test-kid',alg:'RS256',use:'sig'};
    const fetcher=async(url,options)=>{
      calls++;
      assert.equal(url,'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
      assert.equal(options.redirect,'manual');
      return Response.json({keys:[jwk]},{headers:{'Cache-Control':'public, max-age=3600'}});
    };
    const now=Math.floor(Date.now()/1000);
    const sign=claims=>new SignJWT({iss:'https://securetoken.google.com/mobile-app-3479f',aud:'mobile-app-3479f',sub:'synthetic-owner',iat:now,auth_time:now,exp:now+3600,firebase:{sign_in_provider:'anonymous'},...claims}).setProtectedHeader({alg:'RS256',kid:'test-kid'}).sign(key);
    assert.deepEqual(await verifyFirebase(await sign({}),'mobile-app-3479f',fetcher),{uid:'synthetic-owner',anonymous:true});
    assert.equal(calls,1);
    for (const claims of [{aud:'other'},{iss:'https://evil.invalid'},{exp:now-1},{iat:now+600},{auth_time:now+600},{sub:''},{sub:42}])
      await assert.rejects(()=>sign(claims).then(token=>verifyFirebase(token,'mobile-app-3479f',fetcher)),/unauthenticated/);
    const token=await sign({});
    const parts=token.split('.');parts[1]=Buffer.from(JSON.stringify({sub:'forged'})).toString('base64url');
    await assert.rejects(()=>verifyFirebase(parts.join('.'),'mobile-app-3479f',fetcher),/unauthenticated/);
    assert.equal(calls,1);
  } finally { await rm(directory,{recursive:true,force:true}); }
});

test('JWKS rejects malformed keys and refreshes an unknown kid after cooldown',async t=>{
  const {privateKey,publicKey}=await generateKeyPair('RS256');
  const jwk={...await exportJWK(publicKey),kid:'rotation-1',alg:'RS256',use:'sig'};
  const now=Math.floor(Date.now()/1000);
  const sign=kid=>new SignJWT({iss:'https://securetoken.google.com/mobile-app-3479f',aud:'mobile-app-3479f',sub:'synthetic',iat:now,auth_time:now,exp:now+3600}).setProtectedHeader({alg:'RS256',kid}).sign(privateKey);
  const token=await sign(jwk.kid);
  for(const [index,keys] of [[],[jwk,jwk],[{...jwk,kty:'oct'}],[{...jwk,d:'private'}]].entries()){
    const {verifyFirebase:verify}=await import(`../src/auth.mjs?malformed=${index}`);
    await assert.rejects(()=>verify(token,'mobile-app-3479f',async()=>Response.json({keys})),/unauthenticated/);
  }
  const {verifyFirebase:verify}=await import('../src/auth.mjs?rotation');
  let calls=0;
  const fetcher=async()=>{calls++;return Response.json({keys:[{...jwk,kid:calls===1?'rotation-1':'rotation-2'}]},{headers:{'Cache-Control':'max-age=3600'}});};
  await verify(token,'mobile-app-3479f',fetcher);
  const rotated=await sign('rotation-2');
  await assert.rejects(()=>verify(rotated,'mobile-app-3479f',fetcher),/unauthenticated/);
  assert.equal(calls,1);
  t.mock.timers.enable({apis:['Date'],now:Date.now()});
  t.mock.timers.tick(31000);
  assert.equal((await verify(rotated,'mobile-app-3479f',fetcher)).uid,'synthetic');
  assert.equal(calls,2);
});
