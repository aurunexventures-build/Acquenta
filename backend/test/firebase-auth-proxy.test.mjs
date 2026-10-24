import {test} from 'node:test';
import assert from 'node:assert/strict';
import {proxyFirebaseAuth} from '../.test-build/firebase-auth-proxy.mjs';

test('auth helpers preserve queries, status and body without forwarding app credentials', async () => {
 const original=globalThis.fetch;
 try {
  globalThis.fetch=async req=>{
   assert.equal(req.url,'https://metcue09.firebaseapp.com/__/auth/iframe?apiKey=public&target=https%3A%2F%2Fevil.example');
   assert.equal(req.redirect,'manual');
   assert.equal(req.headers.has('authorization'),false);
   assert.equal(req.headers.has('cookie'),false);
   return new Response('<html>auth helper</html>',{status:200,headers:{'Content-Type':'text/html'}});
  };
  const response=await proxyFirebaseAuth(new Request('https://acquenta.aurunex.com/__/auth/iframe?apiKey=public&target=https%3A%2F%2Fevil.example',{headers:{Authorization:'Bearer private',Cookie:'private=session'}}));
  assert.equal(response.headers.get('Cache-Control'),'no-store');
  assert.equal(await response.text(),'<html>auth helper</html>');
 } finally {globalThis.fetch=original;}
});
test('auth POST preserves callback body and Google redirect without following it', async()=>{
 const original=globalThis.fetch;
 try {
  globalThis.fetch=async req=>{
   assert.equal(req.method,'POST');
   assert.equal(await req.text(),'state=example');
   return new Response(null,{status:302,headers:{Location:'https://accounts.google.com/'}});
  };
  const response=await proxyFirebaseAuth(new Request('https://acquenta.aurunex.com/__/auth/handler',{method:'POST',body:'state=example'}));
  assert.equal(response.status,302);
  assert.equal(response.headers.get('location'),'https://accounts.google.com/');
 } finally {globalThis.fetch=original;}
});
test('proxy rejects unrelated routes and unsupported methods',async()=>{
 assert.equal((await proxyFirebaseAuth(new Request('https://acquenta.aurunex.com/api/private'))).status,404);
 assert.equal((await proxyFirebaseAuth(new Request('https://acquenta.aurunex.com/__/auth/handler',{method:'DELETE'}))).status,405);
});
