import {generateKeyPairSync} from 'node:crypto';
import {decodeJwt} from 'jose';
import {firebaseDeletionSession} from '../.test-build/firebase-admin.mjs';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {createAdminHandler} from '../.test-build/admin.mjs';
function fixture(options={}){const db=new DatabaseSync(':memory:');for(const file of ['0000_legacy_schema.sql','0001_wallet_records.sql','0002_photos.sql','0003_account_deletion.sql','0004_admin_moderation.sql','0005_account_profiles.sql','0006_deleted_identity_guard.sql','0007_admin_access.sql'])db.exec(readFileSync(`backend/migrations/${file}`,'utf8'));
const removed={photos:[],vectors:[],identities:[]};
const env={VECTORIZE:{async deleteByIds(ids){if(options.vectorFailure)throw new Error('vector unavailable');removed.vectors.push(...ids);}},ADMIN_EMAILS:'aurunex.ventures@gmail.com',FIREBASE_PROJECT_ID:'metcue09',metcue_db:{prepare(sql){let args=[];return {bind(...v){args=v;return this;},async first(){return db.prepare(sql).get(...args)||null;},async all(){return {results:db.prepare(sql).all(...args)};},async run(){return db.prepare(sql).run(...args);}};},async batch(statements){db.exec('BEGIN');try{for(const statement of statements)await statement.run();db.exec('COMMIT');}catch(e){db.exec('ROLLBACK');throw e;}}},ASSETS:{fetch(){return new Response('<h1>Login</h1>',{headers:{'Content-Type':'text/html'}});}},PHOTOS:{async delete(keys){removed.photos.push(...keys);},async get(){return {body:new Uint8Array([1,2,3])};}}};
const handler=createAdminHandler(async request=>{const identity=request.headers.get('Authorization');if(!identity)throw new Error();return identity==='owner'?{sub:'owner',email:'aurunex.ventures@gmail.com',email_verified:true,auth_time:options.authTime??Date.now()/1000}:identity==='unverified'?{sub:'bad',email:'aurunex.ventures@gmail.com',email_verified:false}:{sub:'stranger',email:'stranger@example.com',email_verified:true};},async()=>{if(options.credentialsFailure)throw new Error('No credentials');return {async lookup(uid){return options.identityEmail?{email:options.identityEmail}:db.prepare('SELECT email FROM users WHERE id=?').get(uid)||null;},async remove(uid){if(options.identityFailure)throw new Error('Firebase unavailable');removed.identities.push(uid);}};});
const call=(path,body,identity='owner',origin='https://admin.test')=>handler.fetch(new Request(`https://admin.test${path}`,{method:body?'POST':'GET',headers:{...(identity?{Authorization:identity}:{}),'Content-Type':'application/json',Origin:origin},...(body?{body:JSON.stringify(body)}:{})}),env);
return {db,call,removed,options};}
test('admin APIs deny missing, ordinary and unverified identities',async()=>{const f=fixture();for(const path of ['/api/users','/api/overview','/api/portraits','/api/audit','/api/me']){assert.equal((await f.call(path,null,null)).status,401);assert.equal((await f.call(path,null,'stranger')).status,403);assert.equal((await f.call(path,null,'unverified')).status,403);}assert.equal((await f.call('/api/me')).status,200);});
test('moderation validates origin, reason and target, and audits reversible changes',async()=>{const f=fixture();f.db.prepare('INSERT INTO users(id,email) VALUES(?,?)').run('alice','alice@test');const action={action:'suspend',target:'alice',reason:'Abusive profile review'};assert.equal((await f.call('/api/moderate',action,'owner','https://evil.test')).status,403);assert.equal((await f.call('/api/moderate',{...action,reason:''})).status,400);assert.equal((await f.call('/api/moderate',{...action,target:'missing'})).status,404);assert.equal((await f.call('/api/moderate',action)).status,200);assert.equal(f.db.prepare('SELECT suspended FROM admin_user_controls').get().suspended,1);assert.equal((await f.call('/api/moderate',{...action,action:'restore-user'})).status,200);assert.equal(f.db.prepare('SELECT suspended FROM admin_user_controls').get().suspended,0);assert.equal(f.db.prepare('SELECT count(*) AS n FROM admin_audit').get().n,2);});
test('portrait review excludes private contact photos, can hide/restore and retains bytes',async()=>{const f=fixture();f.db.exec("INSERT INTO photos(id,user_id,purpose,object_key,content_type) VALUES('11111111-1111-1111-1111-111111111111','alice','portrait','a','image/png'),('22222222-2222-2222-2222-222222222222','alice','connection','b','image/png')");const result=await(await f.call('/api/portraits')).json();assert.equal(result.portraits.length,1);assert.equal((await f.call('/api/portraits/22222222-2222-2222-2222-222222222222')).status,404);const action={action:'hide-photo',target:result.portraits[0].id,reason:'Inappropriate portrait'};assert.equal((await f.call('/api/moderate',action)).status,200);assert.equal(f.db.prepare('SELECT hidden FROM admin_photo_controls').get().hidden,1);assert.equal((await f.call('/api/moderate',{...action,action:'restore-photo'})).status,200);assert.equal(f.db.prepare('SELECT hidden FROM admin_photo_controls').get().hidden,0);assert.equal(f.db.prepare('SELECT count(*) AS n FROM photos').get().n,2);});
test('inventory excludes deleted accounts and does not expose private conversation payloads',async()=>{const f=fixture();f.db.exec("INSERT INTO users(id,email) VALUES('alice','alice@test'),('removed','removed@test'); INSERT INTO wallet_records(user_id,kind,id,payload,version) VALUES('alice','connection','private','{\"rawCue\":\"private note\"}',1);INSERT INTO account_deletions(user_id) VALUES('removed')");const response=await f.call('/api/users');const content=await response.text();assert.ok(!content.includes('private note'));assert.ok(!content.includes('removed@test'));assert.ok(content.includes('alice@test'));});

const deletion={action:'delete-user',target:'alice',confirmation:'alice@test',reason:'Owner requested test account cleanup'};
function seedDeletion(f){
 f.db.exec(`INSERT INTO users(id,email) VALUES('alice','alice@test'),('bob','bob@test');
 INSERT INTO wallet_records(user_id,kind,id,payload,version) VALUES('alice','connection','person','{}',1),('bob','card','keep','{}',1);
 INSERT INTO photos(id,user_id,purpose,object_key,content_type) VALUES('photo-alice','alice','portrait','alice/portrait','image/png'),('photo-bob','bob','portrait','bob/portrait','image/png');
 INSERT INTO account_profiles(user_id,payload,version) VALUES('alice','{}',1);
 INSERT INTO admin_user_controls(user_id,suspended,reason) VALUES('alice',1,'Review');
 INSERT INTO admin_photo_controls(photo_id,hidden,reason) VALUES('photo-alice',1,'Review'),('photo-bob',1,'Keep');`);
}
test('deletion enforces owner, origin, confirmation, recent sign-in and protected identities',async()=>{
 for(const identity of [null,'stranger','unverified']){const f=fixture();seedDeletion(f);assert.equal((await f.call('/api/moderate',deletion,identity)).status,identity?403:401);assert.equal(f.db.prepare('SELECT count(*) n FROM users').get().n,2);}
 const f=fixture();seedDeletion(f);
 assert.equal((await f.call('/api/moderate',deletion,'owner','https://evil.test')).status,403);
 assert.equal((await f.call('/api/moderate',{...deletion,confirmation:'DELETE'})).status,400);
 assert.equal((await f.call('/api/moderate',{...deletion,confirmation:'alice'})).status,400);
 assert.equal((await f.call('/api/moderate',{...deletion,confirmation:'bob@test'})).status,400);
 assert.equal((await f.call('/api/moderate',{...deletion,target:'owner',confirmation:'owner'})).status,403);
 const old=fixture({authTime:Date.now()/1000-3600});seedDeletion(old);assert.equal((await old.call('/api/moderate',deletion)).status,401);
 const protectedUser=fixture({identityEmail:'aurunex.ventures@gmail.com'});seedDeletion(protectedUser);assert.equal((await protectedUser.call('/api/moderate',deletion)).status,403);
 assert.equal(protectedUser.db.prepare('SELECT count(*) n FROM account_deletions').get().n,0);
});
test('deletion removes account cloud data and login, blocks old writes, preserves other users and audits',async()=>{
 const f=fixture();seedDeletion(f);assert.equal((await f.call('/api/moderate',deletion)).status,200);
 assert.equal(f.db.prepare("SELECT id FROM users WHERE id='alice'").get(),undefined);
 assert.equal(f.db.prepare("SELECT count(*) n FROM wallet_records WHERE user_id='alice'").get().n,0);
 assert.equal(f.db.prepare("SELECT count(*) n FROM account_profiles WHERE user_id='alice'").get().n,0);
 assert.deepEqual(f.removed.photos,['alice/portrait']);assert.equal(f.removed.vectors.length,1);assert.deepEqual(f.removed.identities,['alice']);
 assert.equal(f.db.prepare("SELECT count(*) n FROM admin_photo_controls WHERE photo_id='photo-bob'").get().n,1);
 assert.equal(f.db.prepare("SELECT count(*) n FROM wallet_records WHERE user_id='bob'").get().n,1);
 assert.equal(f.db.prepare("SELECT count(*) n FROM users WHERE id='bob'").get().n,1);
 assert.throws(()=>f.db.exec("INSERT INTO wallet_records(user_id,kind,id,payload,version) VALUES('alice','card','stale','{}',1)"),/ACCOUNT_DELETED/);
 assert.equal(f.db.prepare("SELECT count(*) n FROM admin_audit WHERE target='alice' AND action='delete-user'").get().n,1);
 assert.throws(()=>f.db.exec("INSERT INTO users(id,email) VALUES('alice','stale@test')"),/ACCOUNT_DELETED/);
 assert.equal((await(await f.call('/api/deletions')).json()).length,0);
 assert.equal((await f.call('/api/moderate',deletion)).status,200);assert.deepEqual(f.removed.identities,['alice']);
});
test('credentials fail before any deletion and interrupted cleanup remains retryable',async()=>{
 const unavailable=fixture({credentialsFailure:true});seedDeletion(unavailable);assert.equal((await unavailable.call('/api/moderate',deletion)).status,503);assert.equal(unavailable.db.prepare('SELECT count(*) n FROM account_deletions').get().n,0);
 const f=fixture({identityFailure:true});seedDeletion(f);assert.equal((await f.call('/api/moderate',deletion)).status,503);
 assert.equal((await(await f.call('/api/deletions')).json())[0].user_id,'alice');
 f.options.identityFailure=false;assert.equal((await f.call('/api/moderate',deletion)).status,200);
 assert.equal((await(await f.call('/api/deletions')).json()).length,0);
 const vector=fixture({vectorFailure:true});seedDeletion(vector);assert.equal((await vector.call('/api/moderate',deletion)).status,503);
 assert.equal(vector.db.prepare("SELECT count(*) n FROM photos WHERE user_id='alice'").get().n,1);
 vector.options.vectorFailure=false;assert.equal((await vector.call('/api/moderate',deletion)).status,200);
});

test('Firebase deletion credential stays server-side, targets configured project and tolerates already-deleted login',async()=>{
 const {privateKey}=generateKeyPairSync('rsa',{modulusLength:2048});
 const secret=JSON.stringify({project_id:'test-project',client_email:'deleter@test-project.iam.gserviceaccount.com',private_key:privateKey.export({format:'pem',type:'pkcs8'})});
 const originalFetch=globalThis.fetch;const calls=[];
 globalThis.fetch=async(url,options)=>{
  calls.push({url:String(url),options});
  if(String(url)==='https://oauth2.googleapis.com/token'){
   const jwt=decodeJwt(options.body.get('assertion'));assert.equal(jwt.iss,'deleter@test-project.iam.gserviceaccount.com');assert.equal(jwt.scope,'https://www.googleapis.com/auth/identitytoolkit');
   return Response.json({access_token:'server-only-token'});
  }
  assert.equal(options.headers.Authorization,'Bearer server-only-token');
  if(String(url).endsWith(':lookup')){assert.deepEqual(JSON.parse(options.body),{localId:['alice']});return Response.json({users:[{localId:'alice',email:'alice@test'}]});}
  assert.equal(String(url),'https://identitytoolkit.googleapis.com/v1/projects/test-project/accounts:delete');
  assert.deepEqual(JSON.parse(options.body),{localId:'alice'});
  return Response.json({error:{message:'USER_NOT_FOUND'}},{status:400});
 };
 try{
  const env={FIREBASE_PROJECT_ID:'test-project',FIREBASE_ADMIN_SERVICE_ACCOUNT:secret};
  const session=await firebaseDeletionSession(env);assert.equal((await session.lookup('alice')).email,'alice@test');await session.remove('alice');
  assert.equal(calls.length,3);await assert.rejects(()=>firebaseDeletionSession({...env,FIREBASE_PROJECT_ID:'another-project'}));assert.equal(calls.length,3);
 }finally{globalThis.fetch=originalFetch;}
});

test('inventory identifies protected admin accounts and old admin hostname redirects',async()=>{
 const f=fixture();f.db.exec("INSERT INTO users(id,email) VALUES('owner','aurunex.ventures@gmail.com'),('other-admin','AURUNEX.VENTURES@GMAIL.COM'),('regular','regular@test')");
 const users=(await(await f.call('/api/users')).json()).users;
 assert.equal(users.find(u=>u.user_id==='owner').is_admin,true);assert.equal(users.find(u=>u.user_id==='other-admin').is_admin,true);assert.equal(users.find(u=>u.user_id==='regular').is_admin,false);
 const h=createAdminHandler();const r=await h.fetch(new Request('https://admin.metcue.aurunex.com/?test=1'),{});assert.equal(r.status,308);assert.equal(r.headers.get('Location'),'https://admin.acquenta.aurunex.com/?test=1');
});

test('owner grants and revokes admin access; delegated admins cannot manage access or delete users',async()=>{
 const f=fixture();
 assert.equal((await f.call('/api/admins')).status,200);
 assert.equal((await f.call('/api/admins',{action:'grant',email:'bad'})).status,400);
 assert.equal((await f.call('/api/admins',{action:'revoke',email:'aurunex.ventures@gmail.com'})).status,403);
 assert.equal((await f.call('/api/admins',{action:'grant',email:' STRANGER@example.com '})).status,200);
 assert.equal((await f.call('/api/me',null,'stranger')).status,200);
 assert.equal((await (await f.call('/api/me',null,'stranger')).json()).role,'admin');
 assert.equal((await f.call('/api/admins',null,'stranger')).status,403);
 assert.equal((await f.call('/api/admins',{action:'grant',email:'another@example.com'},'stranger')).status,403);
 seedDeletion(f);assert.equal((await f.call('/api/moderate',deletion,'stranger')).status,403);
 assert.equal((await f.call('/api/moderate',{action:'suspend',target:'alice',reason:'Manual review'},'stranger')).status,200);
 assert.equal((await f.call('/api/admins',{action:'revoke',email:'stranger@example.com'})).status,200);
 assert.equal((await f.call('/api/me',null,'stranger')).status,403);
 assert.equal(f.db.prepare("SELECT count(*) n FROM admin_audit WHERE action IN ('grant-admin','revoke-admin')").get().n,2);
});
test('delegated administrator accounts are protected from moderation and deletion',async()=>{
 const f=fixture();seedDeletion(f);f.db.exec("UPDATE users SET email='alice@example.com' WHERE id='alice'");await f.call('/api/admins',{action:'grant',email:'alice@example.com'});
 const inventory=await (await f.call('/api/users')).json();assert.equal(inventory.users.find(u=>u.user_id==='alice').is_admin,true);
 assert.equal((await f.call('/api/moderate',{action:'suspend',target:'alice',reason:'Manual review'})).status,403);
 assert.equal((await f.call('/api/moderate',deletion)).status,403);
});
