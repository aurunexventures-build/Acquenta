import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {assertSafeImage} from '../.test-build/image-safety.mjs';
const image=new Uint8Array([255,216,255,224]);
const safe={adult:'VERY_UNLIKELY',violence:'UNLIKELY',racy:'VERY_UNLIKELY',medical:'POSSIBLE',spoof:'VERY_LIKELY'};
function fixture(){
 const db=new DatabaseSync(':memory:');db.exec(readFileSync('migrations/0009_image_safety.sql','utf8'));
 const env={GOOGLE_VISION_API_KEY:'test-vision',OPENAI_API_KEY:'test-text',metcue_db:{prepare(sql){let args=[];return {bind(...values){args=values;return this;},async first(){return db.prepare(sql).get(...args)??null;},async run(){return db.prepare(sql).run(...args);}};}}};return {db,env};
}
function google(scores=safe,extra={}){return Response.json({responses:[{safeSearchAnnotation:scores,...extra}]});}
test('Google receives only picture bytes; successful identical checks are cached per account',async()=>{
 const {db,env}=fixture();let calls=0;
 const fetcher=async(url,options)=>{calls++;assert.equal(url,'https://vision.googleapis.com/v1/images:annotate');assert.equal(options.headers['x-goog-api-key'],'test-vision');const body=JSON.parse(options.body);assert.deepEqual(body.requests[0].features,[{type:'SAFE_SEARCH_DETECTION'},{type:'TEXT_DETECTION'}]);assert.equal(JSON.stringify(body).includes('alice'),false);return google();};
 await assertSafeImage(env,'alice',image,'image/jpeg',fetcher);await assertSafeImage(env,'alice',image,'image/jpeg',fetcher);assert.equal(calls,1);
 await assertSafeImage(env,'bob',image,'image/jpeg',fetcher);assert.equal(calls,2);assert.equal(db.prepare('SELECT count(*) AS n FROM image_safety_checks').get().n,2);
});
for(const field of ['adult','violence','racy'])test(`Google ${field} POSSIBLE blocks; cached rejection does not call again`,async()=>{
 const {env}=fixture();let calls=0;const fetcher=async()=>{calls++;return google({...safe,[field]:'POSSIBLE'});};
 for(let i=0;i<2;i++)await assert.rejects(assertSafeImage(env,'alice',image,'image/jpeg',fetcher),e=>e.status===422);assert.equal(calls,1);
});
for(const [name,response] of [['unknown',()=>google({...safe,racy:'UNKNOWN'})],['missing',()=>google({adult:'UNLIKELY'})],['provider error',()=>new Response('secret',{status:429})],['malformed',()=>Response.json({})],['oversized',()=>new Response('x'.repeat(512001))]])test(`Google ${name} fails closed without exposing provider errors`,async()=>{
 const {env}=fixture();await assert.rejects(assertSafeImage(env,'alice',image,'image/jpeg',async()=>response()),e=>e.status===503&&!e.message.includes('secret'));
});
test('text found in an otherwise safe image is checked and can block the picture',async()=>{
 const {env}=fixture();let textCalls=0;
 const fetcher=async(url,options)=>{
 if(url.includes('googleapis'))return google(safe,{fullTextAnnotation:{text:'Abusive text fixture'}});
 textCalls++;assert.equal(url,'https://api.openai.com/v1/moderations');assert.deepEqual(JSON.parse(options.body).input,[{type:'text',text:'Abusive text fixture'}]);
 return Response.json({results:[{flagged:true,categories:{sexual:false,'self-harm':false,violence:false,hate:true,harassment:false}}]});};
 await assert.rejects(assertSafeImage(env,'alice',image,'image/jpeg',fetcher),e=>e.status===422);assert.equal(textCalls,1);
});
test('missing OCR text credential fails closed while image-only checks need only Google',async()=>{
 const {env}=fixture();delete env.OPENAI_API_KEY;
 await assert.rejects(assertSafeImage(env,'alice',image,'image/jpeg',async()=>google(safe,{fullTextAnnotation:{text:'text'}})),e=>e.status===503);
});
test('per-user limit blocks uncached pictures before calling the provider',async()=>{
 const {env}=fixture();let calls=0;const fetcher=async()=>{calls++;return google();};
 for(let i=0;i<10;i++)await assertSafeImage(env,'alice',new Uint8Array([i]),'image/jpeg',fetcher);
 await assert.rejects(assertSafeImage(env,'alice',new Uint8Array([11]),'image/jpeg',fetcher),e=>e.status===429);assert.equal(calls,10);
});
test('missing Google credential never calls a different provider',async()=>{
 const {env}=fixture();delete env.GOOGLE_VISION_API_KEY;await assert.rejects(assertSafeImage(env,'alice',image,'image/jpeg',async()=>{throw Error('must not call');}),e=>e.status===503);
});
