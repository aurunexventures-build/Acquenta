import test from 'node:test';
import assert from 'node:assert/strict';
import {recallContext,recallEvidence,rankRecall} from '../.test-build/recall-ai.mjs';
test('recall context is bounded and treats malformed input as empty',()=>{
 assert.deepEqual(recallContext(null),[]);
 assert.deepEqual(recallContext(['old','developers',null,'London','Flutter','not Android']),['developers','London','Flutter','not Android']);
 assert.equal(recallContext(['x'.repeat(2000)])[0].length,1000);
});
test('long histories retain relevant tail evidence and identity',()=>{
 const evidence=recallEvidence({fullName:'Mei',role:'Developer',rawCue:'unrelated '.repeat(1000)+'built Flutter accessibility tools',interactions:[{text:'discussed Dart widgets'}]},'Flutter Dart');
 assert.ok(evidence.includes('Mei'));assert.ok(evidence.includes('Flutter accessibility'));assert.ok(evidence.includes('Dart widgets'));assert.ok(evidence.length<=1800);
});
test('ranking passes context, handles multilingual intent and rejects fabricated evidence',async()=>{
 let captured;
 const env={CUE_MODEL:'test',AI:{run:async(_model,input)=>{captured=JSON.parse(input.messages.at(-1).content);return {response:{interpretation:'Flutter developers',matches:[{id:'mei',score:.9,evidence:'Flutter developer'},{id:'foreign',score:1,evidence:'anything'},{id:'noah',score:.8,evidence:'invented Flutter skill'}]}};}}};
 const result=await rankRecall(env,'केवल Flutter','',[{id:'mei',role:'Flutter developer'},{id:'noah',role:'Web developer'}],['software engineers']);
 assert.deepEqual(captured.context,['software engineers']);assert.equal(captured.query,'केवल Flutter');assert.deepEqual(result.matches.map(m=>m.connection.id),['mei']);
});
