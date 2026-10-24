import test from 'node:test';
import assert from 'node:assert/strict';
import {runTextAI, GROQ_TEXT_MODEL} from '../.test-build/text-ai.mjs';
const input = {messages:[{role:'user',content:'Use the same name'}],max_tokens:900,response_format:{type:'json_schema',json_schema:{type:'object',properties:{name:{type:'string'}},required:['name'],additionalProperties:false}}};
test('existing provider stays active until Groq key is installed',async()=>{
 let called=false;
 const result=await runTextAI({CUE_MODEL:'existing',AI:{run:async(model,body)=>{called=true;assert.equal(model,'existing');assert.equal(body,input);return {response:{name:'Sam'}};}}},input);
 assert.equal(called,true);assert.deepEqual(result.response,{name:'Sam'});
});
test('Groq uses strict schema and returns structured content',async()=>{
 const original=globalThis.fetch;
 try {
 globalThis.fetch=async(url,options)=>{
 assert.equal(url,'https://api.groq.com/openai/v1/chat/completions');
 assert.equal(options.headers.Authorization,'Bearer test-only-key');
 const body=JSON.parse(options.body);
 assert.equal(body.model,GROQ_TEXT_MODEL);assert.equal(body.reasoning_effort,'low');
 assert.equal(body.response_format.json_schema.strict,true);
 assert.deepEqual(body.response_format.json_schema.schema,input.response_format.json_schema);
 return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({name:'Sam'})}}],usage:{prompt_tokens:100,completion_tokens:20}});
 };
 assert.deepEqual(await runTextAI({GROQ_API_KEY:'test-only-key'},input),{response:{name:'Sam'}});
 } finally {globalThis.fetch=original;}
});
for(const [label,response] of [
 ['quota exceeded',()=>new Response('secret provider detail',{status:429})],
 ['truncated output',()=>Response.json({choices:[{finish_reason:'length',message:{content:'{}'}}]})],
 ['invalid JSON',()=>Response.json({choices:[{finish_reason:'stop',message:{content:'not json'}}]})],
 ['oversized response',()=>new Response('x'.repeat(131073))],
]) test(`Groq ${label} preserves a safe retry error without provider fallback`,async()=>{
 const original=globalThis.fetch;
 try {globalThis.fetch=async()=>response();
 await assert.rejects(runTextAI({GROQ_API_KEY:'test-only-key',AI:{run:()=>{throw Error('must not fallback');}}},input),error=>error.status===503&&!error.message.includes('secret'));
 } finally {globalThis.fetch=original;}
});
