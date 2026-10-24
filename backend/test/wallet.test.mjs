import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { requireRecentAuthentication } from '../.test-build/account-deletion.mjs';
import { createHandler } from '../.test-build/worker.mjs';

function fixture() {
  const db=new DatabaseSync(':memory:');
  db.exec(readFileSync('schema.sql','utf8'));
  db.exec(readFileSync('migrations/0001_wallet_records.sql','utf8'));
  db.exec(readFileSync('migrations/0002_photos.sql','utf8'));
  db.exec(readFileSync('migrations/0003_account_deletion.sql','utf8'));
  db.exec(readFileSync('migrations/0004_admin_moderation.sql','utf8'));
  db.exec(readFileSync('migrations/0005_account_profiles.sql','utf8'));
  db.exec(readFileSync('migrations/0006_deleted_identity_guard.sql','utf8'));
  db.exec(readFileSync('migrations/0008_ai_model_usage.sql','utf8'));
  db.exec(readFileSync('migrations/0009_image_safety.sql','utf8'));
  db.exec(readFileSync('migrations/0010_text_safety.sql','utf8'));
  const blobs=new Map();
  const vectors=new Map();let failAi=false,lastEmbedding='';
  const env={
    PHOTOS:{async put(key,bytes,options){blobs.set(key,{bytes:new Uint8Array(bytes),options});},async get(key){const item=blobs.get(key);return item?{body:item.bytes,size:item.bytes.length}:null;},async delete(key){for(const k of Array.isArray(key)?key:[key])blobs.delete(k);}},
    FIREBASE_PROJECT_ID:'test',CUE_MODEL:'@cf/meta/llama-3.2-3b-instruct',
    metcue_db:{prepare(sql){let args=[];return {
      bind(...values){args=values;return this;},
      async first(){return db.prepare(sql).get(...args)??null;},
      async all(){return {results:db.prepare(sql).all(...args)};},
      async run(){return db.prepare(sql).run(...args);},
    };}},
    AI:{async run(model,input){
      if(failAi)throw new Error('offline');
      if(model.includes('bge')){lastEmbedding=input.text[0];return {data:input.text.map(()=>Array(384).fill(0.1))};}
      return {response:JSON.stringify({summary:'Designer who helps with packaging',skills:['Branding'],distinctiveMemory:'Yellow bag',callWhen:['Packaging launch'],followUpQuestion:'Which event was this?'})};
    }},
    VECTORIZE:{async upsert(items){for(const item of items)vectors.set(item.id,item);},async deleteByIds(ids){for(const id of ids)vectors.delete(id);},
      async query(_,options){return {matches:[...vectors.values()].filter(v=>v.namespace===options.namespace).map(v=>({id:v.id,score:0.88}))};}},
  };
  const handler=createHandler(async req=>{const user=req.headers.get('Authorization');if(!user)throw new Error('unauthenticated');return user;},{validateRecent(){},async deleteIdentity(){}},async()=>{},async()=>{});
  async function call(path,body,user='alice',method='POST') {
    const req=new Request(`https://metcue.test${path}`,{method,headers:{...(user?{'Authorization':user}:{}),'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})});
    return handler.fetch(req,env);
  }
  return {db,env,vectors,blobs,call,failAi(value){failAi=value;},get lastEmbedding(){return lastEmbedding;}};
}
const at='2026-10-01T12:00:00.000Z';
const connection=(id='person',overrides={})=>({id,fullName:'Priya',role:'Designer',company:'Studio',headline:'Brand designer',email:'priya@example.com',phone:'+44 123',
  avatarUrl:'',techStack:['Branding'],links:[{id:'social',title:'LinkedIn',type:'linkedin',url:'https://linkedin.com/in/priya'}],
  eventContext:{eventName:'Design Night',location:'London',date:at,notes:'Packaging design',tags:['Illustration']},
  rawCue:'Yellow bag, met beside the stage',cueConversation:[],futureSelfNote:'Ask about packaging',distinctiveMemory:'Yellow bag',microContext:'Beside the stage',vibeTags:['Warm'],callWhen:['Packaging launch'],savedAt:at,updatedAt:at,isFavorite:true,interactions:[],followUpAt:null,followUpNote:'',followUpCompleted:false,...overrides});
const card=(overrides={})=>({id:'my-card',fullName:'Anit',title:'Creative',category:'custom',role:'Creator',links:[],techStack:[],createdAt:at,updatedAt:at,...overrides});
const sync=(connections=[],extra={})=>({protocol:2,connections,cards:[],deleted:[],...extra});

test('all memory fields, links, own cards and reciprocal downloads roundtrip',async()=>{
  const f=fixture();const c=connection();
  let r=await f.call('/api/v1/sync',sync([c],{cards:[card()]}));assert.equal(r.status,200);
  let data=await r.json();assert.deepEqual(data.connections[0],c);assert.equal(data.cards[0].title,undefined);
  assert.match(f.lastEmbedding,/Yellow bag/);assert.match(f.lastEmbedding,/Packaging launch/);assert.match(f.lastEmbedding,/London/);
  r=await f.call('/api/v1/sync',sync());data=await r.json();assert.deepEqual(data.connections[0],c);
});
test('same connection IDs stay isolated across users; search never returns another wallet',async()=>{
  const f=fixture();await f.call('/api/v1/sync',sync([connection()]));
  await f.call('/api/v1/sync',sync([connection('person',{fullName:'Bob private contact'})]),'bob');
  const alice=await (await f.call('/api/v1/search/semantic',{query:'yellow bag'})).json();assert.equal(alice.matches[0].connection.fullName,'Priya');
  const bob=await (await f.call('/api/v1/search/semantic',{query:'private'},'bob')).json();assert.equal(bob.matches[0].connection.fullName,'Bob private contact');
  assert.equal((await f.call('/api/v1/sync',sync(),null)).status,401);
});
test('old clients cannot resurrect deletions or overwrite newer cues',async()=>{
  const f=fixture();await f.call('/api/v1/sync',sync([connection()]));
  const later='2026-10-02T12:00:00.000Z';await f.call('/api/v1/sync',sync([connection('person',{rawCue:'Updated cue',updatedAt:later})]));
  let data=await (await f.call('/api/v1/sync',sync([connection()]))).json();assert.equal(data.connections[0].rawCue,'Updated cue');
  await f.call('/api/v1/sync',sync([],{deleted:[{kind:'connection',id:'person',updatedAt:'2026-10-03T12:00:00Z'}]}));
  data=await (await f.call('/api/v1/sync',sync([connection()]))).json();assert.equal(data.connections.length,0);assert.equal(data.deleted.length,1);
  const search=await (await f.call('/api/v1/search/semantic',{query:'yellow bag'})).json();assert.deepEqual(search.matches,[]);
});
test('AI outage never prevents saving and pending indexing retries',async()=>{
  const f=fixture();f.failAi(true);
  let data=await (await f.call('/api/v1/sync',sync([connection()]))).json();assert.equal(data.connections.length,1);assert.equal(data.indexed,false);
  f.failAi(false);data=await (await f.call('/api/v1/sync',sync())).json();assert.equal(data.indexed,true);assert.equal(f.vectors.size,1);
});
test('cue endpoint returns reviewable suggestions with untouched original; AI failure is explicit',async()=>{
  const f=fixture(),raw='Yellow bag, helps with branding';
  const result=await f.call('/api/v1/cues/generate',{text:raw,eventName:'Design Night'});assert.equal(result.status,200);
  const data=await result.json();assert.equal(data.rawCue,raw);assert.deepEqual(data.cues.skills,['Branding']);
  f.failAi(true);assert.equal((await f.call('/api/v1/cues/generate',{text:raw})).status,503);
});
test('public cards require explicit publication, escape HTML, support reciprocal receipt and revocation',async()=>{
  const f=fixture();await f.call('/api/v1/sync',sync([],{cards:[card({fullName:'<script>alert(1)</script>'})]}));
  assert.equal(f.db.prepare('SELECT count(*) AS n FROM card_shares').get().n,0);
  const data=await (await f.call('/api/v1/cards/publish',{card:card({fullName:'<script>alert(1)</script>'})})).json();
  const token=new URL(data.url).pathname.split('/').pop();
  const page=await f.call(`/c/${token}?event=%3Cimg%20src%3Dx%20onerror%3Dalert(1)%3E`,undefined,null,'GET');
  const html=await page.text();assert.ok(!html.includes('<script>'));assert.ok(html.includes('&lt;script&gt;'));assert.ok(!html.includes('<img'));
  const request=new Request('https://metcue.test/api/v1/reciprocal',{method:'POST',body:new URLSearchParams({token,name:'Priya',contact:'https://linkedin.com/in/priya',note:'Packaging',event:'Design Night'})});
  const handler=createHandler(async()=>{throw new Error('should be public');},undefined,undefined,async()=>{});assert.equal((await handler.fetch(request,f.env)).status,200);
  const wallet=await (await f.call('/api/v1/sync',sync())).json();assert.equal(wallet.connections[0].links[0].url,'https://linkedin.com/in/priya');assert.equal(wallet.connections[0].email,'');
  assert.equal((await f.call('/api/v1/cards/publish',{id:'my-card'},'bob','DELETE')).status,200);
  assert.equal((await f.call(`/api/v1/cards/shared/${token}`,undefined,null,'GET')).status,200);
  await f.call('/api/v1/cards/publish',{id:'my-card'},'alice','DELETE');assert.equal((await f.call(`/api/v1/cards/shared/${token}`,undefined,null,'GET')).status,404);
});
test('deleting a published card removes its public link',async()=>{
  const f=fixture(),data=await (await f.call('/api/v1/cards/publish',{card:card()})).json();
  await f.call('/api/v1/sync',sync([],{deleted:[{kind:'card',id:'my-card',updatedAt:'2026-10-03T12:00:00Z'}]}));
  assert.equal((await f.call(new URL(data.url).pathname,undefined,null,'GET')).status,404);
});
test('legacy schema migrates without losing event location or links',()=>{
  const db=new DatabaseSync(':memory:');db.exec(readFileSync('schema.sql','utf8'));
  db.exec(`INSERT INTO users(id,email) VALUES('alice','alice@example.com'); INSERT INTO saved_connections(id,user_id,full_name,event_name,event_location,event_date,links) VALUES('old','alice','Legacy person','Meetup','London','2026-10-01','[]')`);
  db.exec(readFileSync('migrations/0001_wallet_records.sql','utf8'));const row=db.prepare('SELECT payload FROM wallet_records').get();assert.equal(JSON.parse(row.payload).eventContext.location,'London');
});
test('invalid input is rejected before any wallet writes and AI quotas are enforced',async()=>{
  const f=fixture();assert.equal((await f.call('/api/v1/sync',sync([connection(),connection('bad',{links:[{id:'evil',url:'javascript:alert(1)'}]})]))).status,400);
  assert.equal(f.db.prepare('SELECT count(*) AS n FROM wallet_records').get().n,0);
  f.db.prepare('INSERT INTO ai_usage VALUES(?,?,100)').run('alice',new Date().toISOString().slice(0,10));
  assert.equal((await f.call('/api/v1/search/semantic',{query:'designer'})).status,429);
});

test('Cloudflare serves the public app shell while private APIs still require Firebase',async()=>{
  const f=fixture();
  f.env.ASSETS={async fetch(request){return new Response(`MetCue Flutter shell: ${new URL(request.url).pathname}`,{headers:{'Content-Type':'text/html'}});}};
  const home=await f.call('/',undefined,null,'GET');assert.equal(home.status,200);assert.match(await home.text(),/Flutter shell/);
  const route=await f.call('/wallet',undefined,null,'GET');assert.equal(route.status,200);
  const health=await (await f.call('/health',undefined,null,'GET')).json();
  assert.equal(health.architecture.authentication,'Firebase Auth');assert.equal(health.architecture.database,'Cloudflare D1');
  for(const path of ['/api/v1/sync','/api/v1/cues/generate','/api/v1/search/semantic','/api/v1/cards/publish']) {
    assert.equal((await f.call(path,{},null)).status,401,path);
  }
});

test('one deployment config binds compiled Flutter assets to the existing MetCue Cloudflare resources',()=>{
  const config=JSON.parse(readFileSync('../wrangler.jsonc','utf8'));
  assert.equal(config.main,'backend/src/index.ts');assert.equal(config.assets.directory,'build/web');
  assert.equal(config.assets.binding,'ASSETS');assert.ok(config.assets.run_worker_first.includes('/api/*'));
  assert.equal(config.vars.FIREBASE_PROJECT_ID,'metcue09');assert.equal(config.d1_databases[0].database_name,'metcue-db');
  assert.equal(config.vectorize[0].index_name,'metcue-index');assert.equal(config.ai.binding,'AI');
  assert.equal(config.d1_databases[0].migrations_dir,'backend/migrations');
});

test('ordered migrations bootstrap a fresh Cloudflare D1 database without manual schema setup',()=>{
  const db=new DatabaseSync(':memory:');
  db.exec(readFileSync('migrations/0000_legacy_schema.sql','utf8'));
  db.exec(readFileSync('migrations/0001_wallet_records.sql','utf8'));
  db.prepare('INSERT INTO wallet_records(user_id,kind,id,payload,version) VALUES(?,?,?,?,?)').run('firebase-uid','connection','contact','{}',1);
  assert.equal(db.prepare('SELECT user_id FROM wallet_records').get().user_id,'firebase-uid');
});

test('guided AI receives answers, preserves the original and stops after three follow-ups',async()=>{
  const f=fixture(),conversation=[{question:'What stood out?',answer:'Recycled packaging'},{question:'Where?',answer:'Beside the stage'},{question:'When to reconnect?',answer:'A product launch'}];
  const result=await (await f.call('/api/v1/cues/generate',{text:'Met a designer',conversation})).json();
  assert.equal(result.rawCue,'Met a designer');assert.deepEqual(result.conversation,conversation);assert.equal(result.cues.followUpQuestion,'');
  const c=connection('interview',{cueConversation:conversation});
  const synced=await (await f.call('/api/v1/sync',sync([c]))).json();assert.deepEqual(synced.connections[0].cueConversation,conversation);
  assert.match(f.lastEmbedding,/Recycled packaging/);assert.match(f.lastEmbedding,/product launch/);
  assert.equal((await f.call('/api/v1/cues/generate',{text:'test',conversation:[...conversation,conversation[0]]})).status,400);
});

const jpeg=new Uint8Array([255,216,255,224,0,16,74,70,73,70]);
async function upload(f,purpose,user='alice',bytes=jpeg){
  const request=new Request(`https://metcue.test/api/v1/photos?purpose=${purpose}`,{method:'POST',headers:{Authorization:user,'Content-Type':'image/jpeg'},body:bytes});
  return createHandler(async req=>{const uid=req.headers.get('Authorization');if(!uid)throw new Error();return uid;},undefined,async()=>{},async()=>{}).fetch(request,f.env);
}
test('private R2 photos are owner-only and never exposed as public portraits',async()=>{
  const f=fixture();const response=await upload(f,'connection');assert.equal(response.status,200);
  const ref=(await response.json()).reference,id=ref.split(':')[1];assert.match(ref,/^photo:/);assert.equal(f.blobs.size,1);
  assert.equal((await f.call(`/api/v1/photos/${id}`,undefined,'alice','GET')).status,200);
  assert.equal((await f.call(`/api/v1/photos/${id}`,undefined,'bob','GET')).status,404);
  assert.equal((await f.call(`/api/v1/portraits/${id}`,undefined,null,'GET')).status,404);
  assert.equal((await f.call('/api/v1/sync',sync([connection('stolen',{avatarUrl:ref})]),'bob')).status,400);
  const data=await (await f.call('/api/v1/sync',sync([connection('photo',{avatarUrl:ref})]))).json();assert.equal(data.connections[0].avatarUrl,ref);
});
test('portrait references travel with a card and stop resolving when detached',async()=>{
  const f=fixture(),ref=(await (await upload(f,'portrait')).json()).reference,id=ref.split(':')[1];
  assert.equal((await f.call(`/api/v1/portraits/${id}`,undefined,null,'GET')).status,404);
  await f.call('/api/v1/sync',sync([],{cards:[card({avatarUrl:ref})]}));
  const image=await f.call(`/api/v1/portraits/${id}`,undefined,null,'GET');assert.equal(image.status,200);assert.equal(image.headers.get('Content-Type'),'image/jpeg');
  const share=await (await f.call('/api/v1/cards/publish',{card:card({avatarUrl:ref})})).json();
  const html=await (await f.call(new URL(share.url).pathname,undefined,null,'GET')).text();assert.match(html,/alt="Portrait"/);
  const received=await (await f.call('/api/v1/sync',sync([connection('received',{avatarUrl:ref})]),'bob')).json();assert.equal(received.connections[0].avatarUrl,ref);
  await f.call('/api/v1/sync',sync([],{cards:[card({avatarUrl:'',updatedAt:'2026-10-03T12:00:00Z'})]}));
  assert.equal((await f.call(`/api/v1/portraits/${id}`,undefined,null,'GET')).status,404);
});
test('photo uploads reject spoofed images, oversized data and private portraits on shared identities',async()=>{
  const f=fixture();assert.equal((await upload(f,'portrait','alice',new TextEncoder().encode('<svg onload="alert(1)"></svg>'))).status,400);
  assert.equal((await upload(f,'portrait','alice',new Uint8Array(512*1024+1))).status,413);
  assert.equal(f.blobs.size,0);
  const ref=(await (await upload(f,'connection')).json()).reference;
  assert.equal((await f.call('/api/v1/sync',sync([],{cards:[card({avatarUrl:ref})]}))).status,400);
});


test('follow-up reminders sync privately and validate fields', async()=>{
  const f=fixture();
  const c=connection('reminder',{followUpAt:'2027-01-10T09:00:00.000Z',followUpNote:'Send proposal',followUpCompleted:false});
  let r=await f.call('/api/v1/sync',sync([c])); assert.equal(r.status,200);
  let data=await r.json(); assert.deepEqual(data.connections[0],c);
  data=await (await f.call('/api/v1/sync',sync(), 'bob')).json(); assert.equal(data.connections.length,0);
  r=await f.call('/api/v1/sync',sync([connection('invalid',{followUpAt:'not-a-date'})])); assert.equal(r.status,400);
  r=await f.call('/api/v1/sync',sync([connection('invalid',{followUpNote:'x'.repeat(1001)})])); assert.equal(r.status,400);
  const completed={...c,followUpCompleted:true,updatedAt:'2026-10-02T12:00:00.000Z'};
  data=await (await f.call('/api/v1/sync',sync([completed]))).json(); assert.equal(data.connections[0].followUpCompleted,true);
  const removed={...completed,followUpAt:null,followUpNote:'',followUpCompleted:false,updatedAt:'2026-10-03T12:00:00.000Z'};
  data=await (await f.call('/api/v1/sync',sync([removed]))).json(); assert.equal(data.connections[0].followUpAt,null);
});


test('interaction history survives sync, remains private and is indexed', async()=>{
  const f=fixture();
  const interactions=[{id:'note-one',at,kind:'note',text:'Discussed origami robotics'}];
  const c=connection('history',{interactions});
  const data=await (await f.call('/api/v1/sync',sync([c]))).json();
  assert.deepEqual(data.connections[0].interactions, interactions);
  assert.match(f.lastEmbedding,/origami robotics/);
  const other=await (await f.call('/api/v1/sync',sync(), 'bob')).json(); assert.equal(other.connections.length,0);
  for (const invalid of [[{...interactions[0],kind:'unknown'}], [{...interactions[0],at:'bad-date'}], [{...interactions[0],text:''}], [interactions[0],interactions[0]], Array.from({length:101},(_,i)=>({...interactions[0],id:`n-${i}`}))]) {
    assert.equal((await f.call('/api/v1/sync',sync([connection('bad',{interactions:invalid})]))).status,400);
  }
});

test('profile skills support nontechnical roles, require identity and survive AI failure',async()=>{
  const f=fixture();
  let received;
  f.env.AI.run=async(_,input)=>{received=JSON.parse(input.messages[1].content);return {response:JSON.stringify({skills:['Floral design','Wedding arrangements','Floral design']})};};
  assert.equal((await f.call('/api/v1/profile/skills',{role:'Florist',pitch:'Flowers for special occasions',description:'Weddings'})).status,200);
  assert.equal(received.role,'Florist');
  const r=await f.call('/api/v1/profile/skills',{role:'Florist',pitch:'Flowers'});
  assert.deepEqual((await r.json()).skills,['Floral design','Wedding arrangements']);
  assert.equal((await f.call('/api/v1/profile/skills',{role:'',pitch:'Flowers'})).status,400);
  assert.equal((await f.call('/api/v1/profile/skills',{role:'Florist',pitch:'Flowers'},null)).status,401);
  f.env.AI.run=async()=>({response:'broken'});
  assert.equal((await f.call('/api/v1/profile/skills',{role:'Florist',pitch:'Flowers'})).status,503);
});

test('questionnaire drafting sends only answers and validates generated drafts',async()=>{
  const f=fixture();let received;
  f.env.AI.run=async(_,input)=>{received=JSON.parse(input.messages[1].content);return {response:JSON.stringify({role:'Teacher',pitch:'I help children develop literacy.',skills:['Lesson planning','Literacy']})};};
  const r=await f.call('/api/v1/profile/draft',{work:'I am a teacher',audience:'Primary school children',specialties:'Literacy',privateNotes:'Do not forward'});
  assert.equal(r.status,200);const draft=await r.json();assert.equal(draft.role,'Teacher');assert.deepEqual(draft.skills,['Literacy']);
  assert.deepEqual(received,{work:'I am a teacher',audience:'Primary school children',specialties:'Literacy'});
  assert.equal((await f.call('/api/v1/profile/draft',{work:' '})).status,400);
  assert.equal((await f.call('/api/v1/profile/draft',{work:'Teacher'},null)).status,401);
  f.env.AI.run=async()=>({response:JSON.stringify({role:'',pitch:'I help people learn.',skills:[]})});
  assert.equal((await f.call('/api/v1/profile/draft',{work:'I help people learn'})).status,200);
  f.env.AI.run=async()=>({response:'bad json'});
  assert.equal((await f.call('/api/v1/profile/draft',{work:'Teacher'})).status,503);
});

test('account deletion removes wallet, photos, vectors and shares without affecting another user',async()=>{
  const f=fixture();
  await f.call('/api/v1/sync',sync([connection()],{cards:[card()]}));
  await f.call('/api/v1/sync',sync([connection()],{cards:[card()]}),'bob');
  const share=await (await f.call('/api/v1/cards/publish',{card:card()})).json();
  f.db.prepare("INSERT INTO photos(id,user_id,purpose,object_key,content_type) VALUES('image','alice','connection','alice/image','image/png')").run();
  f.blobs.set('alice/image',{bytes:new Uint8Array([1])});
  assert.equal((await f.call('/api/v1/account',{confirmation:'DELETE'},'alice','DELETE')).status,200);
  for(const table of ['wallet_records','photos','card_shares','ai_usage']) assert.equal(f.db.prepare(`SELECT count(*) AS n FROM ${table} WHERE user_id='alice'`).get().n,0);
  assert.equal(f.blobs.has('alice/image'),false);
  assert.equal([...f.vectors.values()].some(v=>v.namespace==='alice'),false);
  assert.equal((await f.call('/api/v1/account',undefined,'alice','GET')).status,410);
  assert.equal((await f.call('/api/v1/sync',sync([connection()]))).status,410);
  assert.equal((await f.call('/api/v1/cards/shared/'+share.url.split('/').pop(),undefined,null,'GET')).status,404);
  const bob=await (await f.call('/api/v1/sync',sync(),'bob')).json();assert.equal(bob.connections.length,1);
  assert.equal((await f.call('/api/v1/account',{confirmation:'DELETE'},'alice','DELETE')).status,200);
  assert.throws(()=>f.db.prepare("INSERT INTO wallet_records(user_id,kind,id,payload,version) VALUES('alice','card','stale','{}',1)").run(),/ACCOUNT_DELETED/);
});

test('deletion requires explicit confirmation and failed external cleanup can retry',async()=>{
  const f=fixture();await f.call('/api/v1/sync',sync([connection()]));
  assert.equal((await f.call('/api/v1/account',{confirmation:'NO'},'alice','DELETE')).status,400);
  assert.equal(f.db.prepare('SELECT count(*) AS n FROM account_deletions').get().n,0);
  assert.equal((await f.call('/api/v1/account',{confirmation:'DELETE'},null,'DELETE')).status,401);
  const remove=f.env.VECTORIZE.deleteByIds;f.env.VECTORIZE.deleteByIds=async()=>{throw Error('offline');};
  assert.equal((await f.call('/api/v1/account',{confirmation:'DELETE'},'alice','DELETE')).status,503);
  assert.equal(f.db.prepare("SELECT count(*) AS n FROM wallet_records WHERE user_id='alice'").get().n,1);
  assert.equal((await f.call('/api/v1/sync',sync())).status,410);
  f.env.VECTORIZE.deleteByIds=remove;
  assert.equal((await f.call('/api/v1/account',{confirmation:'DELETE'},'alice','DELETE')).status,200);
});

test('account deletion rejects stale or missing recent authentication',()=>{
  const request=authTime=>new Request('https://test/api/v1/account',{headers:{Authorization:'Bearer '+[{},authTime===null?{}:{auth_time:authTime},'sig'].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url')).join('.')}});
  const now=Date.now()/1000;
  assert.doesNotThrow(()=>requireRecentAuthentication(request(now-10)));
  for(const at of [null,now-1000,now+1000]) assert.throws(()=>requireRecentAuthentication(request(at)),error=>error.status===401);
});

test('identity deletion failure remains retryable after cloud cleanup',async()=>{
  const f=fixture();await f.call('/api/v1/sync',sync([connection()]));
  let fail=true;
  const handler=createHandler(async()=> 'alice',{validateRecent(){},async deleteIdentity(){if(fail)throw Error('identity offline');}});
  const remove=()=>handler.fetch(new Request('https://metcue.test/api/v1/account',{method:'DELETE',headers:{'Content-Type':'application/json'},body:JSON.stringify({confirmation:'DELETE'})}),f.env);
  assert.equal((await remove()).status,503);
  assert.equal(f.db.prepare("SELECT count(*) AS n FROM wallet_records WHERE user_id='alice'").get().n,0);
  fail=false;
  assert.equal((await remove()).status,200);
});

test('admin suspension blocks cloud APIs and public cards while preserving account deletion',async()=>{
 const f=fixture();await f.call('/api/v1/sync',sync([],{cards:[card()]}));
 const published=await(await f.call('/api/v1/cards/publish',{card:card()})).json();
 f.db.prepare('INSERT INTO admin_user_controls(user_id,suspended,reason) VALUES(?,1,?)').run('alice','Review');
 assert.equal((await f.call('/api/v1/sync',sync())).status,403);
 assert.equal((await f.call(new URL(published.url).pathname,undefined,null,'GET')).status,403);
 f.db.prepare('UPDATE admin_user_controls SET suspended=0').run();assert.equal((await f.call('/api/v1/sync',sync())).status,200);
});
test('hidden portraits stop resolving publicly and privately, then restore',async()=>{
 const f=fixture();const id='11111111-1111-1111-1111-111111111111';
 f.db.prepare('INSERT INTO photos(id,user_id,purpose,object_key,content_type) VALUES(?,?,?,?,?)').run(id,'alice','portrait','alice/portrait','image/png');
 f.blobs.set('alice/portrait',{bytes:new Uint8Array([137,80,78,71]),options:{}});
 await f.call('/api/v1/sync',sync([],{cards:[card({avatarUrl:`portrait:${id}`})]}));
 assert.equal((await f.call(`/api/v1/portraits/${id}`,undefined,null,'GET')).status,200);
 f.db.prepare('INSERT INTO admin_photo_controls(photo_id,hidden) VALUES(?,1)').run(id);
 assert.equal((await f.call(`/api/v1/portraits/${id}`,undefined,null,'GET')).status,404);
 assert.equal((await f.call(`/api/v1/photos/${id}`,undefined,'alice','GET')).status,404);
 f.db.prepare('UPDATE admin_photo_controls SET hidden=0').run();
 assert.equal((await f.call(`/api/v1/portraits/${id}`,undefined,null,'GET')).status,200);
});

test('single-pass memory organisation never returns follow-up questions',async()=>{
 const f=fixture();
 const r=await f.call('/api/v1/cues/generate',{text:'Priya builds Android apps',askFollowUp:false});
 assert.equal(r.status,200);assert.equal((await r.json()).cues.followUpQuestion,'');
 f.env.AI.run=async()=>({response:JSON.stringify({summary:'',followUpQuestion:'What else?'})});
 const fallback=await (await f.call('/api/v1/cues/generate',{text:'Priya creates Android applications.',askFollowUp:false})).json();
 assert.equal(fallback.cues.summary,'Priya creates Android applications.');
});

test('search wording organisation preserves original on failure and requires authentication',async()=>{
 const f=fixture();let sent;
 f.env.AI.run=async(_,input)=>{sent=JSON.parse(input.messages[1].content);return {response:JSON.stringify({text:'Android apps, met recently'})};};
 const r=await f.call('/api/v1/text/organise',{text:'Um the person who makes Android apps, met recently',purpose:'search'});
 assert.equal(r.status,200);assert.equal((await r.json()).text,'Android apps, met recently');
 assert.match(sent.text,/Android/);
 assert.equal((await f.call('/api/v1/text/organise',{text:'Android',purpose:'search'},null)).status,401);
 f.env.AI.run=async()=>({response:'bad json'});
 assert.equal((await f.call('/api/v1/text/organise',{text:'Android',purpose:'search'})).status,503);
});

test('card field cleanup uses only supplied facts and requires a field and authentication',async()=>{
 const f=fixture();let prompt,sent;
 f.env.AI.run=async(_,input)=>{prompt=input.messages[0].content;sent=JSON.parse(input.messages[1].content);return {response:JSON.stringify({text:'I build Android apps with Flutter.'})};};
 const body={purpose:'card',field:'One-line pitch *',text:'um I build Android apps with Flutter'};
 const r=await f.call('/api/v1/text/organise',body);
 assert.equal(r.status,200);assert.equal((await r.json()).text,'I build Android apps with Flutter.');
 assert.equal(sent.field,body.field);assert.equal(sent.text,body.text);
 assert.match(prompt,/Do not answer or ask questions/);assert.match(prompt,/Preserve all supplied facts/);
 assert.equal((await f.call('/api/v1/text/organise',body,null)).status,401);
 assert.equal((await f.call('/api/v1/text/organise',{...body,field:''})).status,400);
 f.env.AI.run=async()=>({response:'not json'});
 assert.equal((await f.call('/api/v1/text/organise',body)).status,503);
});

test('five free cards are enforced per account; edits and same-sync slot reuse work',async()=>{
 const f=fixture();
 for(let i=1;i<=5;i++)assert.equal((await f.call('/api/v1/sync',sync([],{cards:[card({id:`card-${i}`})]}))).status,200);
 const sixth=await f.call('/api/v1/sync',sync([],{cards:[card({id:'card-6'})]}));
 assert.equal(sixth.status,409);assert.match((await sixth.json()).error,/5 cards/);
 assert.equal(f.db.prepare("SELECT COUNT(*) n FROM wallet_records WHERE user_id='alice' AND kind='card' AND deleted=0").get().n,5);
 assert.equal((await f.call('/api/v1/sync',sync([],{cards:[card({id:'card-1',title:'Edited',updatedAt:'2026-10-02T12:00:00Z'})]}))).status,200);
 assert.equal((await f.call('/api/v1/sync',sync([],{cards:[card({id:'card-6'})]}),'bob')).status,200);
 assert.equal((await f.call('/api/v1/sync',sync([],{deleted:[{kind:'card',id:'card-2',updatedAt:'2026-10-03T12:00:00Z'}],cards:[card({id:'card-6'})]}))).status,200);
 assert.equal(f.db.prepare("SELECT COUNT(*) n FROM wallet_records WHERE user_id='alice' AND kind='card' AND deleted=0").get().n,5);
 assert.equal((await f.call('/api/v1/sync',sync([],{cards:[card({id:'card-2'})]}))).status,200);
 assert.equal(f.db.prepare("SELECT deleted FROM wallet_records WHERE user_id='alice' AND id='card-2'").get().deleted,1);
});

test('skill extraction accepts paragraphs and returns separate explicit skill tags',async()=>{
 const f=fixture();let prompt,sent;
 f.env.AI.run=async(_,input)=>{prompt=input.messages[0].content;sent=JSON.parse(input.messages[1].content);return {response:JSON.stringify({skills:['Plumbing','Bathroom fitting','Android development']})};};
 const description='I am a plumber and fit bathrooms. I also create Android apps. '+ 'This is my work experience. '.repeat(45);
 assert.ok(description.length>1000);
 const r=await f.call('/api/v1/profile/skills',{description,mode:'extract'});
 assert.equal(r.status,200);assert.deepEqual((await r.json()).skills,['Plumbing','Bathroom fitting','Android development']);
 assert.equal(sent.description,description.trim());assert.match(prompt,/only from the supplied description/);
 assert.equal((await f.call('/api/v1/profile/skills',{description:'a'.repeat(3001),mode:'extract'})).status,400);
});

test('private About Me profile syncs independently of cards, rejects invalid emails and isolates accounts',async()=>{
 const f=fixture();
 const profile={firstName:'Sam',lastName:'Patel',phone:'+44123456789',emails:['sam@example.com','work@example.com'],
   role:'Designer',company:'Studio',intro:'I design wedding flowers.',
   links:[{id:'profile-social',title:'LinkedIn',type:'linkedin',url:'https://www.linkedin.com/in/sam-patel'}],updatedAt:at};
 assert.equal((await f.call('/api/v1/profile',undefined,null,'GET')).status,401);
 assert.deepEqual((await (await f.call('/api/v1/profile',undefined,'alice','GET')).json()).profile,null);
 assert.equal((await f.call('/api/v1/profile',{profile})).status,200);
 assert.deepEqual((await (await f.call('/api/v1/profile',undefined,'alice','GET')).json()).profile,profile);
 assert.equal((await (await f.call('/api/v1/profile',undefined,'bob','GET')).json()).profile,null);
 const later={...profile,phone:'+44987654321',updatedAt:'2026-10-02T12:00:00Z'};
 await f.call('/api/v1/profile',{profile:later});
 const stale=await (await f.call('/api/v1/profile',{profile})).json();
 assert.equal(stale.profile.phone,later.phone);
 assert.equal((await f.call('/api/v1/profile',{profile:{...profile,emails:['invalid']}})).status,400);
 assert.equal((await f.call('/api/v1/profile',{profile:{...profile,emails:['sam@example.com','SAM@example.com']}})).status,400);
 assert.equal((await f.call('/api/v1/profile',{profile:{...profile,firstName:''}})).status,400);
 const wallet=await (await f.call('/api/v1/sync',sync([],{cards:Array.from({length:5},(_,i)=>card({id:`own-${i}`}))}))).json();
 assert.equal(wallet.cards.length,5);assert.equal(wallet.connections.length,0);
 assert.ok(wallet.cards.every(c=>!Object.hasOwn(c,'emails')));
 assert.equal((await f.call('/api/v1/account',{confirmation:'DELETE'},'alice','DELETE')).status,200);
 assert.equal(f.db.prepare("SELECT COUNT(*) n FROM wallet_records WHERE user_id='alice'").get().n,0);
 assert.equal(f.db.prepare("SELECT COUNT(*) n FROM account_profiles WHERE user_id='alice'").get().n,0);
 assert.equal((await f.call('/api/v1/profile',undefined,'alice','GET')).status,410);
});


test('card conversation cleans full identity, asks skills and audience before returning a card', async () => {
  const f=fixture(); let sent;
  const extracted={cardName:'Creative card',purpose:'Professional',fullName:'Amit Singh',role:'Senior IT Architect',pitch:'I help teams integrate enterprise systems.',specialties:'System integration',audience:'Engineering teams',skills:['System integration'],clarifyField:null,clarification:null};
  f.env.AI.run=async(_,input)=>{sent=JSON.parse(input.messages[1].content);return {response:extracted};};
  const conversation=[{field:0,answer:'You can call it as a creative card. Show it as Amit Singh, a senior IT architect.'}];
  const request=()=>f.call('/api/v1/profile/draft',{mode:'conversation',conversation:JSON.stringify(conversation),privateNotes:'must not be sent'});
  let result=await (await request()).json();
  assert.equal(result.answers[0],'Creative card');assert.equal(result.answers[2],'Amit Singh');
  assert.equal(result.next,5);assert.equal(result.card,null);
  assert.deepEqual(Object.keys(sent),['conversation']);
  conversation.push({field:5,answer:'My specialty is system integration.'});
  result=await (await request()).json();assert.equal(result.next,6);assert.equal(result.card,null);
  conversation.push({field:6,answer:'Engineering teams.'});
  result=await (await request()).json();assert.equal(result.next,-1);assert.equal(result.card.role,'Senior IT Architect');assert.deepEqual(result.card.skills,['System integration']);
  assert.equal((await f.call('/api/v1/profile/draft',{mode:'conversation',conversation:'not JSON'})).status,400);
  assert.equal((await f.call('/api/v1/profile/draft',{mode:'conversation',conversation:JSON.stringify(conversation)},null)).status,401);
});

test('ambiguous speech asks clarification and malformed AI never becomes a card', async () => {
  const f=fixture();
  f.env.AI.run=async()=>({response:{cardName:'Creative',purpose:'Work',fullName:'Ani Singh',role:'Senior IT Architect for massages',pitch:null,specialties:null,audience:null,skills:[],clarifyField:'role',clarification:'What did you mean by for massages?'}});
  const body={mode:'conversation',conversation:JSON.stringify([{field:3,answer:'A senior IT architect for massages'}])};
  let result=await (await f.call('/api/v1/profile/draft',body)).json();
  assert.equal(result.answers[3],null);assert.equal(result.next,3);assert.match(result.question,/massages/);assert.equal(result.card,null);
  f.env.AI.run=async()=>({response:'broken'});
  assert.equal((await f.call('/api/v1/profile/draft',body)).status,503);
});


test('literal null model sentinels never become spoken questions or card names', async () => {
  const f=fixture();
  f.env.AI.run=async()=>({response:{cardName:'Creative',purpose:'Professional',fullName:'null',role:'null',pitch:'null',specialties:'null',audience:'null',skills:[],clarifyField:'fullName',clarification:'null'}});
  const r=await f.call('/api/v1/profile/draft',{mode:'conversation',conversation:JSON.stringify([{field:0,answer:'Call it Creative, for work'}])});
  const result=await r.json();assert.equal(result.next,2);assert.equal(result.answers[2],null);assert.equal(result.question,'What name should appear on this card?');
});


test('cleaned specialties survive when a small model omits its skill array', async () => {
  const f=fixture();f.env.AI.run=async()=>({response:{cardName:'Creative',purpose:'Work',fullName:'Amit Singh',role:'IT Architect',pitch:'I help teams integrate systems.',specialties:'Enterprise architecture, System integration',audience:'Engineering teams',skills:[],clarifyField:null,clarification:null}});
  const r=await f.call('/api/v1/profile/draft',{mode:'conversation',conversation:JSON.stringify([{field:0,answer:'Call it Creative'},{field:5,answer:'My skills are enterprise architecture and system integration'},{field:6,answer:'Engineering teams'}])});
  const result=await r.json();assert.equal(result.next,-1);assert.deepEqual(result.card.skills,['Enterprise architecture','System integration']);
});


test('confirmed profile names retain exact spelling; later card-specific names remain independent', async () => {
  const f=fixture();let sent;
  f.env.AI.run=async(_,input)=>{sent=JSON.parse(input.messages[1].content);return {response:{cardName:'Creative',purpose:'Work',fullName:'Amit Singh',role:'Architect',pitch:'I help teams connect systems.',specialties:null,audience:null,skills:[],clarifyField:'fullName',clarification:'Please spell your name'}};};
  const conversation=[{field:2,answer:'Yes, use this name',profileNameConfirmed:true},{field:0,answer:'Call it Creative, for work'}];
  const body={mode:'conversation',profileName:'Ánīt Singh',conversation:JSON.stringify(conversation)};
  let result=await (await f.call('/api/v1/profile/draft',body)).json();
  assert.equal(result.answers[2],'Ánīt Singh');assert.notEqual(result.next,2);assert.equal(sent.confirmedProfileName,'Ánīt Singh');
  conversation.push({field:2,answer:'Show Amit Singh on this card instead'});body.conversation=JSON.stringify(conversation);
  result=await (await f.call('/api/v1/profile/draft',body)).json();
  assert.equal(sent.confirmedProfileName,undefined);assert.equal(result.next,2); // It may clarify the alternative; never force the old name back.
  assert.equal(f.db.prepare('SELECT COUNT(*) AS count FROM account_profiles').get().count,0);
});


test('final copyediting corrects grammar without changing the confirmed name or skills', async () => {
  const f=fixture();let calls=0;
  f.env.AI.run=async(_,input)=>{
    calls++;
    if(calls===2){assert.equal(JSON.parse(input.messages[1].content).pitch,'I helps teams connects there systems.');return {response:{pitch:'I help teams connect their systems.',bio:'I work with engineering teams on system integration.'}};}
    return {response:{cardName:'Creative',purpose:'Work',fullName:'Wrong spelling',role:'Architect',pitch:'I helps teams connects there systems.',specialties:'System integration',audience:'Engineering teams',skills:['System integration'],clarifyField:null,clarification:null}};
  };
  const r=await f.call('/api/v1/profile/draft',{mode:'conversation',profileName:'Ánīt Singh',conversation:JSON.stringify([{field:2,answer:'Yes',profileNameConfirmed:true},{field:5,answer:'System integration'},{field:6,answer:'Engineering teams'}])});
  const result=await r.json();assert.equal(calls,2);assert.equal(result.card.fullName,'Ánīt Singh');assert.equal(result.card.pitch,'I help teams connect their systems.');assert.equal(result.card.bio,'I work with engineering teams on system integration.');assert.deepEqual(result.card.skills,['System integration']);
});


test('legacy spoken confirmation reuses only the signed-in owners profile', async () => {
  const f=fixture();
  f.db.prepare('INSERT INTO account_profiles(user_id,payload,version) VALUES(?,?,?)').run('alice',JSON.stringify({firstName:'Anit @',lastName:'AuruNex Ventures'}),1);
  f.env.AI.run=async()=>({response:{cardName:'Work',purpose:'Professional',fullName:'Yes you can use the same name',role:null,pitch:null,specialties:null,audience:null,skills:[],clarifyField:null,clarification:null}});
  const body={mode:'conversation',conversation:JSON.stringify([{field:2,answer:'Yes, you can use the same name'}])};
  let result=await (await f.call('/api/v1/profile/draft',body)).json();
  assert.equal(result.answers[2],'Anit @ AuruNex Ventures');assert.notEqual(result.next,2);
  result=await (await f.call('/api/v1/profile/draft',body,'bob')).json();
  assert.equal(result.answers[2],null);assert.equal(result.next,2);
});


test('brief conversation reuses identity and drafts a title without asking administrative questions', async()=>{
 const f=fixture();let calls=0;
 f.env.AI.run=async()=>({response:JSON.stringify(++calls===1?{
 cardName:null,purpose:null,fullName:null,role:'Florist',pitch:'I create wedding flowers.',specialties:'Floral design',audience:'Couples planning weddings',skills:['Floral design'],clarifyField:null,clarification:null
 }:{pitch:'I create wedding flowers.',bio:'I create wedding flowers for couples planning their celebrations.'})});
 const result=await (await f.call('/api/v1/profile/draft',{mode:'conversation',conversationStyle:'brief',profileName:'Sam',conversation:JSON.stringify([{field:4,answer:'I am a florist. I create wedding flowers for couples. My skill is floral design.'}])})).json();
 assert.equal(result.next,-1);assert.equal(result.card.fullName,'Sam');assert.equal(result.card.cardName,'Florist card');
 assert.deepEqual(result.card.skills,['Floral design']);
});
test('brief conversation asks for skills only when not supplied',async()=>{
 const f=fixture();f.env.AI.run=async()=>({response:JSON.stringify({cardName:null,purpose:null,fullName:null,role:'Florist',pitch:'I create wedding flowers.',specialties:null,audience:'Couples',skills:[],clarifyField:null,clarification:null})});
 const data=await (await f.call('/api/v1/profile/draft',{mode:'conversation',conversationStyle:'brief',profileName:'Sam',conversation:JSON.stringify([{field:4,answer:'I create wedding flowers for couples.'}])})).json();
 assert.equal(data.next,5);assert.equal(data.question,'What skills or specialties would you like to highlight?');assert.equal(data.card,null);
});
test('speech endpoints require authentication, reject excessive text, and preserve private recordings',async()=>{
 const f=fixture();f.env.GROQ_API_KEY='test-key';
 assert.equal((await f.call('/api/v1/speech/speak',{text:'Hello'},null)).status,401);
 assert.equal((await f.call('/api/v1/speech/speak',{text:'a'.repeat(201)})).status,400);
 assert.equal((await f.call('/api/v1/speech/transcribe',{audio:'not base64'})).status,400);
 const original=globalThis.fetch;
 try {
 globalThis.fetch=async(url,options)=>{
  assert.equal(options.headers.Authorization,'Bearer test-key');
  if(url.endsWith('/speech')) {
   const body=JSON.parse(options.body);assert.equal(body.voice,'troy');assert.equal(body.model,'canopylabs/orpheus-v1-english');
   return new Response(new Uint8Array([82,73,70,70,0,0,0,0,87,65,86,69]));
  }
  assert.equal(options.body.get('model'),'whisper-large-v3');assert.equal(options.body.has('language'),false);
  return Response.json({text:'I am an architect in Bengaluru.'});
 };
 const audio=await (await f.call('/api/v1/speech/speak',{text:'Hello'})).json();assert.equal(audio.mimeType,'audio/wav');
 const transcript=await (await f.call('/api/v1/speech/transcribe',{audio:btoa('test recording bytes')})).json();
 assert.equal(transcript.text,'I am an architect in Bengaluru.');assert.equal(f.blobs.size,0);
 const usage=f.db.prepare('SELECT model,calls,succeeded,characters FROM ai_model_usage ORDER BY model').all();assert.equal(usage.length,2);assert.equal(usage.find(row=>row.model==='whisper-large-v3').calls,1);assert.equal(usage.find(row=>row.model==='canopylabs/orpheus-v1-english').characters,5);assert.ok(usage.every(row=>row.succeeded===1));
 } finally {globalThis.fetch=original;}
});


test('spoken employer is returned on the card instead of a saved profile employer',async()=>{
 const f=fixture();await f.call('/api/v1/profile',{profile:{firstName:'Anit',company:'Zorro Expenses',emails:[],links:[],updatedAt:at}});
 let calls=0;f.env.AI.run=async()=>({response:JSON.stringify(++calls===1?{
 cardName:'Architecture',purpose:'professional',fullName:'Anit',role:'IT Architect',company:'Forest Mazars',pitch:'I integrate enterprise systems.',specialties:'System integration',audience:'Engineering teams',skills:['System integration'],clarifyField:null,clarification:null
 }:{pitch:'I integrate enterprise systems.',bio:'I work as an IT architect at Forest Mazars.'})});
 const result=await (await f.call('/api/v1/profile/draft',{mode:'conversation',conversationStyle:'brief',profileName:'Anit',conversation:JSON.stringify([{field:4,answer:'I am an IT architect at Forest Mazars, specialising in system integration for engineering teams.'}])})).json();
 assert.equal(result.card.company,'Forest Mazars');
 const profile=await (await f.call('/api/v1/profile',undefined,'alice','GET')).json();
 assert.equal(profile.profile.company,'Zorro Expenses');
});


test('fast conversation remembers understood skills and name, keeps latest corrections, and copyedits in one call',async()=>{
 const f=fixture();let calls=0,sent;
 f.env.AI.run=async(_,input)=>{calls++;sent=JSON.parse(input.messages.at(-1).content);return {response:{cardName:null,purpose:null,fullName:null,company:'New Studio',role:'Designer',pitch:'I design packaging.',bio:'I design packaging at New Studio for small businesses.',specialties:null,audience:'Small businesses',skills:[],clarifyField:null,clarification:null}};};
 const prior={answers:['Creative','Professional','Sam','Designer','I design packaging.','Packaging, Branding',null],company:'Old Studio',skills:['Packaging','Branding']};
 const result=await (await f.call('/api/v1/profile/draft',{mode:'conversation',conversationStyle:'brief',conversationVersion:'2',previousDraft:JSON.stringify(prior),profileName:'Sam',conversation:JSON.stringify([{field:4,answer:'I design packaging. My skills are packaging and branding.'},{field:6,question:'Who would you like to connect with?',answer:'Small businesses. I now work at New Studio.'}])})).json();
 assert.equal(calls,1);assert.equal(result.next,-1);assert.deepEqual(result.card.skills,['Packaging','Branding']);assert.equal(result.card.company,'New Studio');assert.equal(result.card.fullName,'Sam');assert.match(result.card.bio,/New Studio/);assert.deepEqual(sent.previousDraft.skills,['Packaging','Branding']);
});
test('skills volunteered in another turn are retained even if specialties is null',async()=>{
 const f=fixture();f.env.AI.run=async()=>({response:{cardName:'Work',purpose:'Work',fullName:'Sam',role:'Designer',pitch:'I design packaging.',company:'',bio:'I design packaging.',specialties:null,audience:null,skills:['Packaging','Branding'],clarifyField:null,clarification:null}});
 const result=await (await f.call('/api/v1/profile/draft',{mode:'conversation',conversationStyle:'brief',conversationVersion:'2',conversation:JSON.stringify([{field:4,answer:'I design packaging. My skills are packaging and branding.'}])})).json();
 assert.equal(result.next,6);assert.match(result.answers[5],/Packaging/);assert.deepEqual(result.context.skills,['Packaging','Branding']);
});
test('genuine ambiguity and explicit skill removal override previous understood values',async()=>{
 const f=fixture();f.env.AI.run=async()=>({response:{cardName:'Work',purpose:'Work',fullName:'Sam',role:null,pitch:'I help teams.',company:'',bio:'I help teams.',specialties:'',audience:'Teams',skills:[],clarifyField:'role',clarification:'Do you mean systems architecture or building architecture?'}});
 const result=await (await f.call('/api/v1/profile/draft',{mode:'conversation',conversationStyle:'brief',conversationVersion:'2',previousDraft:JSON.stringify({answers:['Work','Work','Sam','Architect','I help teams.','System integration','Teams'],skills:['System integration'],company:''}),conversation:JSON.stringify([{field:3,answer:'Actually I am a different kind of architect, and remove my skill tags.'}])})).json();
 assert.equal(result.next,3);assert.equal(result.answers[3],null);assert.equal(result.answers[5],'');assert.deepEqual(result.context.skills,[]);
});


test('fast name-only reply asks card purpose before work, without assuming a category',async()=>{
 const f=fixture();f.env.AI.run=async()=>({response:{cardName:null,purpose:null,fullName:'Amit Singh',role:null,pitch:null,company:'',bio:'',specialties:null,audience:null,skills:[],clarifyField:null,clarification:null}});
 const result=await (await f.call('/api/v1/profile/draft',{mode:'conversation',conversationStyle:'brief',conversationVersion:'2',profileName:'Sam',conversation:JSON.stringify([{field:2,answer:'Use Amit Singh instead.'}])})).json();
 assert.equal(result.next,1);assert.equal(result.answers[2],'Amit Singh');assert.equal(result.answers[1],null);
});


test('new card drafts omit card names, keep purpose private, and enforce a 120 character pitch',async()=>{
 const f=fixture();let requested;
 const facts={purpose:null,fullName:'Sam',role:'Florist',pitch:'I create wedding flowers for couples.',company:'Bloom',bio:'I create wedding flowers at Bloom.',specialties:'Floral design',audience:'Couples',skills:['Floral design'],clarifyField:null,clarification:null};
 f.env.AI.run=async(_,input)=>{requested=input;return {response:facts};};
 const body={mode:'conversation',conversationStyle:'brief',conversationVersion:'3',profileName:'Sam',conversation:JSON.stringify([{field:4,answer:'I create wedding flowers at Bloom. My skill is floral design. I help couples.'}])};
 const result=await (await f.call('/api/v1/profile/draft',body)).json();
 assert.equal(result.next,-1);assert.equal(result.answers[0],'');assert.equal(result.card.cardName,undefined);assert.ok(result.card.pitch.length<=120);
 assert.equal(requested.response_format.json_schema.properties.cardName,undefined);
 facts.pitch='a'.repeat(121);assert.equal((await f.call('/api/v1/profile/draft',body)).status,503);
});
test('public shares omit private purpose, primary status and legacy card labels',async()=>{
 const f=fixture();const published=await (await f.call('/api/v1/cards/publish',{card:card({title:'Private label',category:'personal',isDefault:true})})).json();
 const token=new URL(published.url).pathname.split('/').pop();
 // Cover a previously published payload too, before a device resync.
 f.db.prepare('UPDATE card_shares SET payload=? WHERE token=?').run(JSON.stringify({...card(),title:'Old private label',category:'event',isDefault:true}),token);
 const shared=await (await f.call('/api/v1/cards/shared/'+token,undefined,null,'GET')).json();
 assert.equal(shared.card.title,undefined);assert.equal(shared.card.category,undefined);assert.equal(shared.card.isDefault,undefined);assert.equal(shared.card.fullName,'Anit');
});


test('private wallet order syncs but is removed from public cards',async()=>{
 const f=fixture();const payload=card({walletOrder:3});
 const result=await (await f.call('/api/v1/sync',sync([],{cards:[payload]}))).json();
 assert.equal(result.cards[0].walletOrder,3);
 const published=await (await f.call('/api/v1/cards/publish',{card:payload})).json();
 const token=new URL(published.url).pathname.split('/').pop();
 const shared=await (await f.call('/api/v1/cards/shared/'+token,undefined,null,'GET')).json();
 assert.equal(shared.card.walletOrder,undefined);
 assert.equal((await f.call('/api/v1/sync',sync([],{cards:[card({walletOrder:-1})]}))).status,400);
});


test('web voice search accepts WAV and rejects unsupported audio types',async()=>{
 const f=fixture(); f.env.GROQ_API_KEY='test-key';
 const original=globalThis.fetch;
 try {
  globalThis.fetch=async(_url,options)=>{
   const file=options.body.get('file');
   assert.equal(file.type,'audio/wav'); assert.equal(file.name,'reply.wav');
   assert.equal(options.body.get('model'),'whisper-large-v3');
   return Response.json({text:'Find the architect from Bengaluru'});
  };
  const response=await f.call('/api/v1/speech/transcribe',{audio:btoa('recorded WAV bytes'),mimeType:'audio/wav'});
  assert.equal(response.status,200);assert.equal((await response.json()).text,'Find the architect from Bengaluru');
  assert.equal((await f.call('/api/v1/speech/transcribe',{audio:btoa('bytes'),mimeType:'text/html'})).status,400);
 } finally {globalThis.fetch=original;}
});


test('AI recall interprets colloquial queries and ranks only supported contacts from this wallet',async()=>{
 const f=fixture();
 await f.call('/api/v1/sync',sync([
  connection('android',{fullName:'Arjun',role:'Android developer',techStack:['Kotlin']}),
  connection('flutter',{fullName:'Mei',role:'Flutter developer',techStack:['Dart']}),
  connection('plumber',{fullName:'Owen',role:'Plumber',techStack:['Pipework']})
 ]));
 await f.call('/api/v1/sync',sync([connection('private',{fullName:'Private person'})]),'bob');
 f.vectors.clear(); // Ranking must work even before the vector index has caught up.
 const original=f.env.AI.run;let calls=0;
 f.env.AI.run=async(model,input)=>{
  if(model.includes('bge'))return original(model,input);
  calls++;
  const data=JSON.parse(input.messages.at(-1).content);
  assert.equal(data.query,'techie');
  assert.ok(data.profiles.some(p=>p.id==='flutter'));assert.ok(!data.profiles.some(p=>p.id==='private'));
  return {response:JSON.stringify({interpretation:'Developers and IT specialists',matches:[{id:'flutter',score:.92,evidence:'Flutter developer'},{id:'android',score:.9,evidence:'Android developer'},{id:'private',score:.99,evidence:'Private person'},{id:'plumber',score:.99,evidence:'Software engineer'}]})};
 };
 const r=await f.call('/api/v1/search/semantic',{query:'techie'});assert.equal(r.status,200);
 const data=await r.json();assert.equal(data.aiReranked,true);assert.match(data.interpretation,/IT specialists/);
 assert.deepEqual(data.matches.map(m=>m.connection.id),['flutter','android']);
 assert.ok(data.matches.every(m=>m.reason.startsWith('Saved evidence:')));assert.equal(calls,1);
});
test('recall provider failure explicitly falls back to semantic matches',async()=>{
 const f=fixture();await f.call('/api/v1/sync',sync([connection()]));
 const original=f.env.AI.run;
 f.env.AI.run=async(model,input)=>{if(model.includes('bge'))return original(model,input);throw Error('AI unavailable');};
 const data=await (await f.call('/api/v1/search/semantic',{query:'designer'})).json();
 assert.equal(data.aiReranked,false);assert.equal(data.matches[0].connection.id,'person');assert.match(data.aiStatus,/unavailable/);
});

test('reconnect drafts load only the signed-in owner contact and fail safely',async()=>{
 const f=fixture();await f.call('/api/v1/sync',sync([connection('alice-only')]));
 assert.equal((await f.call('/api/v1/reconnect/draft',{connectionId:'alice-only'},'bob')).status,404);
 assert.equal((await f.call('/api/v1/reconnect/draft',{})).status,400);
 const original=f.env.AI.run;
 f.env.AI.run=async(model,input)=>{if(model.includes('bge'))return original(model,input);const data=JSON.parse(input.messages.at(-1).content);assert.equal(data.fullName,'Priya');assert.match(data.rawCue,/Yellow bag/);return {response:{draft:'Hi Priya, how is the packaging work going?'}};};
 const result=await f.call('/api/v1/reconnect/draft',{connectionId:'alice-only'});
 assert.equal(result.status,200);assert.equal((await result.json()).aiGenerated,true);
 f.env.AI.run=async()=>{throw Error('offline');};assert.equal((await f.call('/api/v1/reconnect/draft',{connectionId:'alice-only'})).status,503);
});
test('short multilingual recall and refinement context reach AI without losing ownership',async()=>{
 const f=fixture();await f.call('/api/v1/sync',sync([connection()]));
 const original=f.env.AI.run;
 f.env.AI.run=async(model,input)=>{if(model.includes('bge'))return original(model,input);const data=JSON.parse(input.messages.at(-1).content);assert.equal(data.query,'AI');assert.deepEqual(data.context,['लंदन में डिजाइनर']);return {response:{interpretation:'AI designers in London',matches:[]}};};
 const result=await f.call('/api/v1/search/semantic',{query:'AI',context:['लंदन में डिजाइनर']});
 assert.equal(result.status,200);assert.equal((await result.json()).aiReranked,true);
});

test('photo moderation rejects before storage and checks legacy pictures before serving',async()=>{
 const f=fixture();f.env.GOOGLE_VISION_API_KEY='test-vision';let checks=0;
 const original=globalThis.fetch;
 globalThis.fetch=async()=>{checks++;return Response.json({responses:[{safeSearchAnnotation:{adult:'POSSIBLE',violence:'UNLIKELY',racy:'UNLIKELY',medical:'UNLIKELY',spoof:'UNLIKELY'}}]});};
 try {
 const handler=createHandler(async()=> 'alice');
 const response=await handler.fetch(new Request('https://metcue.test/api/v1/photos?purpose=portrait',{method:'POST',body:jpeg}),f.env);
 assert.equal(response.status,422);assert.equal(checks,1);assert.equal(f.blobs.size,0);assert.equal(f.db.prepare('SELECT count(*) AS n FROM photos').get().n,0);
 const id='22222222-2222-4222-8222-222222222222';
 f.db.prepare('INSERT INTO photos(id,user_id,purpose,object_key,content_type) VALUES(?,?,?,?,?)').run(id,'alice','portrait','legacy','image/jpeg');
 f.blobs.set('legacy',{bytes:jpeg,options:{}});
 await f.call('/api/v1/sync',sync([],{cards:[card({avatarUrl:`portrait:${id}`})]}));
 const legacy=await handler.fetch(new Request(`https://metcue.test/api/v1/portraits/${id}`),f.env);
 assert.equal(legacy.status,422);assert.equal(f.blobs.size,1,'Legacy bytes remain private; account is not deleted');
 assert.equal(checks,1,'Cached rejection still prevents legacy image access');
 } finally {globalThis.fetch=original;}
});
test('unconfigured production photo moderation never accepts an upload',async()=>{
 const f=fixture();const response=await createHandler(async()=> 'alice').fetch(new Request('https://metcue.test/api/v1/photos?purpose=portrait',{method:'POST',body:jpeg}),f.env);
 assert.equal(response.status,503);assert.equal(f.blobs.size,0);
});

test('account deletion removes safety decisions but preserves anonymised service call totals',async()=>{
 const f=fixture();await f.call('/api/v1/sync',sync());
 f.db.prepare('INSERT INTO image_safety_usage(month,day,user_id,calls) VALUES(?,?,?,?)').run('2026-10',1,'alice',3);
 f.db.prepare('INSERT INTO image_safety_checks(user_id,fingerprint,verdict,categories,model,checked_at) VALUES(?,?,?,?,?,?)').run('alice','hash','passed','[]','test',1);
 assert.equal((await f.call('/api/v1/account',{confirmation:'DELETE'},'alice','DELETE')).status,200);
 assert.equal(f.db.prepare('SELECT count(*) AS n FROM image_safety_checks').get().n,0);
 const usage=f.db.prepare('SELECT * FROM image_safety_usage').get();assert.equal(usage.calls,3);assert.match(usage.user_id,/^deleted:/);
});

test('text checks reject complete sync batch before modifying previous cards',async()=>{
 const f=fixture();await f.call('/api/v1/sync',sync([],{cards:[card({headline:'Safe headline'})]}));
 const old=f.db.prepare("SELECT payload FROM wallet_records WHERE kind='card'").get().payload;
 const handler=createHandler(async()=> 'alice',undefined,undefined,async(_env,_uid,value)=>{if(value.includes('Fuck'))throw Error('blocked');});
 const result=await handler.fetch(new Request('https://metcue.test/api/v1/sync',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(sync([],{cards:[card({headline:'Fuck',updatedAt:'2026-10-02T12:00:00Z'})],deleted:[{kind:'card',id:'my-card',updatedAt:'2026-10-02T12:00:00Z'}]}))}),f.env);
 assert.equal(result.status,503);assert.equal(f.db.prepare("SELECT payload FROM wallet_records WHERE kind='card'").get().payload,old);assert.equal(f.db.prepare("SELECT deleted FROM wallet_records WHERE kind='card'").get().deleted,0);
});
test('production text paths block standalone profanity without provider credentials',async()=>{
 const f=fixture(),handler=createHandler(async()=> 'alice');
 const call=(path,body)=>handler.fetch(new Request('https://metcue.test'+path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),f.env);
 for(const path of ['/api/v1/cards/publish','/api/v1/text/check'])assert.equal((await call(path,{card:card({headline:'Fuck'})})).status,422);
 assert.equal((await call('/api/v1/profile',{profile:{firstName:'Sam',lastName:'Test',intro:'Fuck off',emails:[],links:[],updatedAt:at}})).status,422);
 assert.equal((await call('/api/v1/sync',sync([],{cards:[card({headline:'Fuck'})]}))).status,422);
});

test('text preflight does not reject unsaved local timestamps or require a saved record ID',async()=>{
 const f=fixture(),handler=createHandler(async()=> 'alice',undefined,undefined,async()=>{});
 const response=await handler.fetch(new Request('https://metcue.test/api/v1/text/check',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({card:{fullName:'Sam',role:'Architect',updatedAt:'2099-10-24T16:30:00'}})}),f.env);
 assert.equal(response.status,200);assert.equal((await response.json()).safe,true);
 assert.equal(f.db.prepare('SELECT count(*) AS n FROM wallet_records').get().n,0);
});

test('card appearance survives sync for own and received cards',async()=>{
 const f=fixture();const appearance={cardFinish:'linen',themeColorHex:'#234B42'};
 const response=await f.call('/api/v1/sync',sync([connection('styled',appearance)],{cards:[card(appearance)]}));
 assert.equal(response.status,200);let data=await response.json();
 for(const item of [data.cards[0],data.connections[0]]) {assert.equal(item.cardFinish,'linen');assert.equal(item.themeColorHex,'#234B42');}
 data=await(await f.call('/api/v1/sync',sync())).json();assert.equal(data.cards[0].cardFinish,'linen');assert.equal(data.connections[0].themeColorHex,'#234B42');
});
