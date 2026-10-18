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
  const handler=createHandler(async req=>{const user=req.headers.get('Authorization');if(!user)throw new Error('unauthenticated');return user;},{validateRecent(){},async deleteIdentity(){}});
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
  let data=await r.json();assert.deepEqual(data.connections[0],c);assert.equal(data.cards[0].title,'Creative');
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
  const handler=createHandler(async()=>{throw new Error('should be public');});assert.equal((await handler.fetch(request,f.env)).status,200);
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
  return createHandler(async req=>{const uid=req.headers.get('Authorization');if(!uid)throw new Error();return uid;}).fetch(request,f.env);
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
