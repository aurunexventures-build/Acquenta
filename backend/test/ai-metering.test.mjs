import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {meterAI,captureTokens,captureQuota,runEmbeddings} from '../.test-build/ai-metering.mjs';
import {runTextAI} from '../.test-build/text-ai.mjs';
function fixture(){const db=new DatabaseSync(':memory:');db.exec(readFileSync('migrations/0008_ai_model_usage.sql','utf8'));const env={metcue_db:{prepare(sql){let args=[];return {bind(...values){args=values;return this;},async run(){return db.prepare(sql).run(...args);}};}}};return {db,env};}
test('model metering aggregates calls and tokens across requests, counts failures, and stores no prompt or identity',async()=>{
 const {env,db}=fixture();
 await Promise.all(Array.from({length:4},()=>meterAI(env,'groq','model',async metrics=>{captureTokens(metrics,{usage:{prompt_tokens:100,completion_tokens:20}});return 'private response';})));
 await assert.rejects(()=>meterAI(env,'groq','model',async()=>{throw Error('provider failed');}));
 const row=db.prepare('SELECT * FROM ai_model_usage').get();assert.equal(row.calls,5);assert.equal(row.succeeded,4);assert.equal(row.failed,1);assert.equal(row.input_tokens,400);assert.equal(row.output_tokens,80);assert.equal(row.token_responses,4);assert.ok(!JSON.stringify(row).includes('private response'));
});
test('provider quota accepts only safe known headers, preserves newer snapshots, and missing measurements remain unknown',async()=>{
 const {env,db}=fixture();
 await meterAI(env,'groq','model',async metrics=>{captureQuota(metrics,new Headers({'x-ratelimit-limit-requests':'1000','x-ratelimit-remaining-requests':'900','x-ratelimit-reset-requests':'1h2m3.4s','x-ratelimit-limit-tokens':'8000','x-ratelimit-remaining-tokens':'6000','authorization':'secret','x-ratelimit-reset-tokens':'secret text'}));captureTokens(metrics,{usage:{prompt_tokens:NaN,completion_tokens:-5}});});
 const quota=JSON.parse(db.prepare('SELECT headers FROM ai_provider_quota').get().headers);assert.equal(quota['limit-requests'],'1000');assert.equal(quota['remaining-tokens'],'6000');assert.equal(quota['reset-tokens'],undefined);assert.ok(!JSON.stringify(quota).includes('secret'));
 await meterAI(env,'groq','model',async metrics=>{metrics.quota={'limit-requests':'10'};metrics.observedAt='2000-01-01T00:00:00Z';});
 assert.equal(JSON.parse(db.prepare('SELECT headers FROM ai_provider_quota').get().headers)['limit-requests'],'1000');
 assert.equal(db.prepare('SELECT token_responses FROM ai_model_usage').get().token_responses,0);
});
test('metering faults preserve AI output and original errors',async()=>{
 const env={metcue_db:{prepare(){throw Error('DB offline');}}};
 assert.equal(await meterAI(env,'groq','model',async()=>42),42);
 await assert.rejects(()=>meterAI(env,'groq','model',async()=>{throw Error('original provider failure');}),/original provider failure/);
});
test('Groq text calls persist usage and quota even on rate-limit failure without provider fallback',async()=>{
 const {env,db}=fixture();env.GROQ_API_KEY='test-key';const original=globalThis.fetch;
 try{globalThis.fetch=async()=>Response.json({choices:[{finish_reason:'stop',message:{content:'{"text":"sample"}'}}],usage:{prompt_tokens:23,completion_tokens:7}},{headers:{'x-ratelimit-limit-requests':'1000','x-ratelimit-remaining-requests':'999','x-ratelimit-reset-requests':'24h'}});
 assert.deepEqual(await runTextAI(env,{messages:[]}),{response:{text:'sample'}});
 globalThis.fetch=async()=>new Response('private error',{status:429,headers:{'x-ratelimit-limit-requests':'1000','x-ratelimit-remaining-requests':'0'}});
 await assert.rejects(()=>runTextAI(env,{messages:[]}));
 const row=db.prepare('SELECT * FROM ai_model_usage').get();assert.equal(row.calls,2);assert.equal(row.failed,1);assert.equal(row.input_tokens,23);assert.equal(row.output_tokens,7);
 assert.equal(JSON.parse(db.prepare('SELECT headers FROM ai_provider_quota').get().headers)['remaining-requests'],'0');
 }finally{globalThis.fetch=original;}
});
test('embedding batches are counted once per provider invocation and separate from text calls',async()=>{
 const {env,db}=fixture();env.AI={run:async(model,input)=>({data:input.text.map(()=>[1,2])})};
 await runEmbeddings(env,['a','b','c']);await runEmbeddings(env,['query']);
 const row=db.prepare('SELECT * FROM ai_model_usage').get();assert.equal(row.calls,2);assert.equal(row.provider,'cloudflare');assert.equal(row.model,'@cf/baai/bge-small-en-v1.5');assert.equal(row.token_responses,0);
});
