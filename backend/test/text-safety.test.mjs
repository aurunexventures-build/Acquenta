import test from 'node:test';import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';import {readFileSync} from 'node:fs';
import {assertSafeText,googleTextVerdict,cardText} from '../.test-build/text-safety/text_safety.js';
import {hasProfanity} from '../.test-build/text-safety/profanity.js';
const safe={Toxic:.01,Derogatory:.01,Violent:.01,Sexual:.01,Insult:.01,Profanity:.01,Health:.99,Finance:.99};
const response=(scores=safe)=>Response.json({moderationCategories:Object.entries(scores).map(([name,confidence])=>({name,confidence}))});
function fixture(){const db=new DatabaseSync(':memory:');db.exec(readFileSync('migrations/0010_text_safety.sql','utf8'));const env={GOOGLE_TEXT_MODERATION_API_KEY:'test-only',metcue_db:{prepare(sql){let args=[];return {bind(...v){args=v;return this;},async first(){return db.prepare(sql).get(...args)??null;},async run(){return db.prepare(sql).run(...args);}};}}};return {db,env};}
for(const value of ['Fuck','fuck off','f.u.c.k','f*ck','fucking','motherfucker','bullshit','asshole','FUCK','fu\u200bck','ＦＵＣＫ'])test(`strict profanity: ${value}`,()=>assert.equal(hasProfanity(value),true));
for(const value of ['Scunthorpe','Dickinson','Assistant architect','Cumulative returns','Sexual health counsellor','Finance and religion'])test(`legitimate text: ${value}`,()=>assert.equal(hasProfanity(value),false));
test('profanity blocks without a Google call or credential',async()=>{let calls=0;await assert.rejects(assertSafeText({},'alice','Fuck',async()=>{calls++;}),e=>e.status===422);assert.equal(calls,0);});
test('Google uses only selected harmful categories; benign health/finance are allowed',async()=>{
 assert.equal(await googleTextVerdict('test','Doctor and finance consultant',async(url,opt)=>{assert.equal(url,'https://language.googleapis.com/v1/documents:moderateText');assert.equal(JSON.parse(opt.body).document.type,'PLAIN_TEXT');return response();}),'passed');
 assert.equal(await googleTextVerdict('test','contextual abuse',async()=>response({...safe,Insult:.9})),'flagged');
});
for(const [label,value] of [['missing',{Toxic:.1}],['invalid',{...safe,Profanity:2}],['empty',{}]])test(`incomplete Google ${label} verdict fails closed`,async()=>{assert.equal(await googleTextVerdict('test','text',async()=>response(value)),'unavailable');});
test('provider failures do not become approvals',async()=>{assert.equal(await googleTextVerdict('test','text',async()=>new Response('private detail',{status:403})),'unavailable');});
test('unchanged content is cached per account and storage contains no original text',async()=>{
 const {env,db}=fixture();let calls=0;const fetcher=async()=>{calls++;return response();};
 await assertSafeText(env,'alice','Software engineer',fetcher);await assertSafeText(env,'alice','Software engineer',fetcher);assert.equal(calls,1);
 await assertSafeText(env,'bob','Software engineer',fetcher);assert.equal(calls,2);assert.ok(!JSON.stringify(db.prepare('SELECT * FROM text_safety_checks').all()).includes('Software engineer'));
});
test('monthly unit limit blocks before provider use',async()=>{const {env,db}=fixture();const now=new Date();db.prepare('INSERT INTO text_safety_usage VALUES(?,?,?,?,?)').run(now.toISOString().slice(0,7),Math.floor(+now/86400000),'other',1,5000);await assert.rejects(assertSafeText(env,'alice','Software engineer',async()=>{throw Error('must not call');}),e=>e.status===429);});
test('private memory, purpose and contact identifiers are not sent as card text',()=>{assert.equal(cardText({fullName:'Mei',role:'Developer',category:'private purpose',rawCue:'private note',email:'personal@example.com',phone:'123'}),'Mei\nDeveloper');});
