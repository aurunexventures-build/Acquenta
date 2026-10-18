import {deleteAccountData} from '../../backend/src/account_deletion';
import {firebaseDeletionSession} from './firebase_admin';
import {createRemoteJWKSet,jwtVerify, type JWTPayload} from 'jose';
const keys=createRemoteJWKSet(new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'));
const headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','X-Frame-Options':'DENY','Strict-Transport-Security':'max-age=31536000'};
const json=(data:unknown,status=200)=>Response.json(data,{status,headers});
export async function verify(request:Request,env:Env):Promise<JWTPayload>{
 const bearer=request.headers.get('Authorization');
 if(!bearer?.startsWith('Bearer '))throw new Error('Sign in required.');
 return (await jwtVerify(bearer.slice(7),keys,{issuer:`https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,audience:env.FIREBASE_PROJECT_ID,algorithms:['RS256']})).payload;
}
export function allowed(payload:JWTPayload,env:Env){return Boolean(payload.sub&&payload.email_verified===true&&typeof payload.email==='string'&&env.ADMIN_EMAILS.split(',').map(e=>e.trim().toLowerCase()).includes(payload.email.toLowerCase()));}
async function administrator(email:string,env:Env){
 return env.ADMIN_EMAILS.split(',').some(value=>value.trim().toLowerCase()===email.toLowerCase())||Boolean(await env.metcue_db.prepare('SELECT email FROM admin_access WHERE email=?').bind(email.toLowerCase()).first());
}
export function createAdminHandler(authenticate=verify, deletionSession=firebaseDeletionSession){return {async fetch(request:Request,env:Env):Promise<Response>{
 const url=new URL(request.url);
 if(url.hostname==='admin.metcue.aurunex.com'){url.hostname='admin.acquenta.aurunex.com';return Response.redirect(url.toString(),308);}
 try{
  if(!url.pathname.startsWith('/api/')){
   const response=await env.ASSETS.fetch(request);const h=new Headers(response.headers);
   for(const [k,v]of Object.entries(headers))h.set(k,v);
   h.set('Content-Security-Policy',"default-src 'self'; script-src 'self' https://www.gstatic.com https://apis.google.com; style-src 'self'; img-src 'self' blob:; connect-src 'self' https://identitytoolkit.googleapis.com https://securetoken.googleapis.com https://*.googleapis.com https://metcue09.firebaseapp.com https://apis.google.com; frame-src https://metcue09.firebaseapp.com https://accounts.google.com; base-uri 'none'; frame-ancestors 'none'; form-action 'self'");
   return new Response(response.body,{status:response.status,headers:h});
  }
  let actor:JWTPayload;try{actor=await authenticate(request,env);}catch{return json({error:'Please sign in again.'},401);}
  const isOwner=allowed(actor,env);
  if(!isOwner&&!(actor.sub&&actor.email_verified===true&&typeof actor.email==='string'&&await administrator(actor.email,env)))return json({error:'This account does not have administrator access. Use the approved owner account with a verified email.'},403);
  if(request.method!=='GET'&&request.headers.get('Origin')!==url.origin)return json({error:'Invalid request origin.'},403);
  if(url.pathname==='/api/me'&&request.method==='GET')return json({email:actor.email,uid:actor.sub,role:isOwner?'owner':'admin'});
  if(url.pathname==='/api/admins'){
   if(!isOwner)return json({error:'Only the owner can manage administrators.'},403);
   if(request.method==='GET')return json({owners:env.ADMIN_EMAILS.split(',').map(email=>email.trim()),admins:(await env.metcue_db.prepare('SELECT email,granted_by,created_at FROM admin_access ORDER BY created_at,email').all()).results});
   if(request.method==='POST'){
    if(!request.headers.get('Content-Type')?.startsWith('application/json'))return json({error:'JSON required.'},415);
    const reader=request.body?.getReader();if(!reader)return json({error:'Body required.'},400);let raw='';const decoder=new TextDecoder();let size=0;while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>2048){await reader.cancel();return json({error:'Request too large.'},413);}raw+=decoder.decode(part.value,{stream:true});}raw+=decoder.decode();
    let body;try{body=JSON.parse(raw);}catch{return json({error:'Invalid JSON.'},400);}
    const email=typeof body?.email==='string'?body.email.trim().toLowerCase():'';
    if(email.length>254||! /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||!['grant','revoke'].includes(body?.action))return json({error:'Enter a valid email and action.'},400);
    if(env.ADMIN_EMAILS.split(',').some(value=>value.trim().toLowerCase()===email))return json({error:'Owner access is protected.'},403);
    await env.metcue_db.batch([
     body.action==='grant'?env.metcue_db.prepare('INSERT INTO admin_access(email,granted_by) VALUES(?,?) ON CONFLICT(email) DO NOTHING').bind(email,String(actor.email)):env.metcue_db.prepare('DELETE FROM admin_access WHERE email=?').bind(email),
     env.metcue_db.prepare('INSERT INTO admin_audit(id,actor,action,target,reason) VALUES(?,?,?,?,?)').bind(crypto.randomUUID(),String(actor.email),body.action+'-admin',email,'Owner '+body.action+'ed administrator access'),
    ]);return json({success:true});
   }
   return json({error:'Method not allowed.'},405);
  }
  if(url.pathname==='/api/overview'&&request.method==='GET'){
   const summary=await env.metcue_db.prepare(`SELECT
    (SELECT count(*) FROM (SELECT user_id FROM wallet_records UNION SELECT id FROM users UNION SELECT user_id FROM photos) o WHERE NOT EXISTS(SELECT 1 FROM account_deletions d WHERE d.user_id=o.user_id)) AS users,
    (SELECT count(*) FROM wallet_records WHERE kind='card' AND deleted=0) AS cards,
    (SELECT count(*) FROM photos WHERE purpose='portrait') AS portraits,
    (SELECT count(*) FROM admin_user_controls WHERE suspended=1) AS suspended,
    (SELECT count(*) FROM admin_photo_controls WHERE hidden=1) AS hidden,
    (SELECT coalesce(sum(calls),0) FROM ai_usage WHERE day=date('now') AND user_id NOT LIKE 'form:%') AS aiToday`).first();
   return json(summary);
  }
  if(url.pathname==='/api/users'&&request.method==='GET'){
   const q=(url.searchParams.get('q')||'').slice(0,200);const offset=Math.max(0,Math.min(100000,Number(url.searchParams.get('offset'))||0));
   const result=await env.metcue_db.prepare(`WITH owners AS (SELECT user_id FROM wallet_records UNION SELECT id FROM users UNION SELECT user_id FROM photos)
    SELECT o.user_id,coalesce(u.email,'') AS email,coalesce(u.display_name,'') AS display_name,
    coalesce(c.suspended,0) AS suspended,coalesce(c.reason,'') AS reason,
    (SELECT count(*) FROM wallet_records r WHERE r.user_id=o.user_id AND r.kind='card' AND r.deleted=0) AS cards,
    (SELECT count(*) FROM wallet_records r WHERE r.user_id=o.user_id AND r.kind='connection' AND r.deleted=0) AS connections,
    (SELECT max(version) FROM wallet_records r WHERE r.user_id=o.user_id) AS last_sync,
    (SELECT json_extract(payload,'$.fullName') FROM wallet_records r WHERE r.user_id=o.user_id AND r.kind='card' AND r.deleted=0 LIMIT 1) AS card_name
    FROM owners o LEFT JOIN users u ON u.id=o.user_id LEFT JOIN admin_user_controls c ON c.user_id=o.user_id
    WHERE NOT EXISTS(SELECT 1 FROM account_deletions d WHERE d.user_id=o.user_id)
    AND (o.user_id LIKE ? OR u.email LIKE ? OR u.display_name LIKE ? OR EXISTS(SELECT 1 FROM wallet_records w WHERE w.user_id=o.user_id AND w.kind='card' AND w.deleted=0 AND json_extract(w.payload,'$.fullName') LIKE ?))
    ORDER BY last_sync DESC,o.user_id LIMIT 51 OFFSET ?`).bind(...Array(4).fill(`%${q}%`),offset).all();
   return json({users:await Promise.all(result.results.slice(0,50).map(async(row:any)=>({...row,is_admin:row.user_id===actor.sub||await administrator(String(row.email),env)}))),more:result.results.length>50});
  }
  if(url.pathname==='/api/portraits'&&request.method==='GET'){
   const offset=Math.max(0,Math.min(100000,Number(url.searchParams.get('offset'))||0));
   const result=await env.metcue_db.prepare(`SELECT p.id,p.user_id,p.created_at,coalesce(c.hidden,0) AS hidden,coalesce(c.reason,'') AS reason,
    (SELECT json_extract(payload,'$.fullName') FROM wallet_records w WHERE w.user_id=p.user_id AND w.kind='card' AND w.deleted=0 LIMIT 1) AS name
    FROM photos p LEFT JOIN admin_photo_controls c ON c.photo_id=p.id WHERE p.purpose='portrait'
    AND NOT EXISTS(SELECT 1 FROM account_deletions d WHERE d.user_id=p.user_id)
    ORDER BY p.created_at DESC,p.id LIMIT 51 OFFSET ?`).bind(offset).all();
   return json({portraits:result.results.slice(0,50),more:result.results.length>50});
  }
  const photo=/^\/api\/portraits\/([\w-]{36})$/.exec(url.pathname);
  if(photo&&request.method==='GET'){
   const row=await env.metcue_db.prepare("SELECT object_key,content_type FROM photos WHERE id=? AND purpose='portrait' AND NOT EXISTS(SELECT 1 FROM account_deletions d WHERE d.user_id=photos.user_id)").bind(photo[1]).first<{object_key:string;content_type:string}>();
   if(!row)return json({error:'Portrait unavailable.'},404);const image=await env.PHOTOS.get(row.object_key);
   if(!image)return json({error:'Portrait unavailable.'},404);
   return new Response(image.body,{headers:{...headers,'Content-Type':row.content_type,'Content-Security-Policy':"default-src 'none'"}});
  }
  if(url.pathname==='/api/audit'&&request.method==='GET')return json((await env.metcue_db.prepare('SELECT * FROM admin_audit ORDER BY created_at DESC,rowid DESC LIMIT 100').all()).results);
  if(url.pathname==='/api/deletions'&&request.method==='GET'){
   return json((await env.metcue_db.prepare(`SELECT a.target AS user_id,max(a.created_at) AS requested_at,CASE WHEN json_valid(a.reason) THEN json_extract(a.reason,'$.confirmationEmail') ELSE NULL END AS email
    FROM admin_audit a WHERE a.action='delete-user-requested'
    AND NOT EXISTS(SELECT 1 FROM admin_audit done WHERE done.target=a.target AND done.action='delete-user')
    GROUP BY a.target ORDER BY requested_at DESC LIMIT 100`).all()).results);
  }
  if(url.pathname==='/api/moderate'&&request.method==='POST'){
   if(!request.headers.get('Content-Type')?.startsWith('application/json'))return json({error:'JSON required.'},415);
   const reader=request.body?.getReader();if(!reader)return json({error:'Body required.'},400);
   let size=0;const parts:Uint8Array[]=[];while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>4096){await reader.cancel();return json({error:'Request too large.'},413);}parts.push(part.value);}
   const raw=new Uint8Array(size);let at=0;for(const part of parts){raw.set(part,at);at+=part.length;}
   let body;try{body=JSON.parse(new TextDecoder().decode(raw));}catch{return json({error:'Invalid JSON.'},400);}
   if(!body||typeof body!=='object')return json({error:'Invalid action.'},400);
   const {action,target,reason,confirmation}=body;
   if(!['suspend','restore-user','hide-photo','restore-photo','delete-user'].includes(action)||typeof target!=='string'||target.length>128||!target||typeof reason!=='string'||reason.trim().length<5||reason.length>1000)return json({error:'Choose an action and provide a reason (5–1000 characters).'},400);
   if(action==='delete-user'){
    if(!isOwner)return json({error:'Only the owner can permanently delete users.'},403);
    if(target===actor.sub)return json({error:'The owner account is protected.'},403);
    if(typeof actor.auth_time!=='number'||actor.auth_time>Date.now()/1000+30||Date.now()/1000-actor.auth_time>300)return json({error:'Please confirm your owner sign-in again before deleting a user.'},401);
    const stored=await env.metcue_db.prepare('SELECT email FROM users WHERE id=?').bind(target).first<{email:string}>();

    if(stored?.email&&await administrator(stored.email,env))return json({error:'The owner account is protected.'},403);
    const completed=await env.metcue_db.prepare("SELECT id FROM admin_audit WHERE target=? AND action='delete-user' LIMIT 1").bind(target).first();
    if(completed)return json({success:true,alreadyDeleted:true});
    const exists=await env.metcue_db.prepare('SELECT id FROM users WHERE id=? UNION SELECT user_id FROM wallet_records WHERE user_id=? UNION SELECT user_id FROM photos WHERE user_id=? UNION SELECT user_id FROM account_deletions WHERE user_id=?').bind(target,target,target,target).first();
    if(!exists)return json({error:'Record unavailable.'},404);
    let session;let expectedEmail='';try{session=await deletionSession(env);const identity=await session.lookup(target);if(identity?.email&&await administrator(identity.email,env))return json({error:'The owner account is protected.'},403);
     const prior=await env.metcue_db.prepare("SELECT reason FROM admin_audit WHERE target=? AND action='delete-user-requested' ORDER BY created_at DESC LIMIT 1").bind(target).first<{reason:string}>();let priorEmail='';try{priorEmail=JSON.parse(prior?.reason||'{}').confirmationEmail||'';}catch{}
     expectedEmail=identity?.email||stored?.email||priorEmail;
    }catch{return json({error:'Account deletion is temporarily unavailable. No data has been changed. Please retry.'},503);}
    if(!expectedEmail||typeof confirmation!=='string'||confirmation!==expectedEmail)return json({error:'Type the exact account email address to confirm permanent deletion.'},400);
    await env.metcue_db.prepare('INSERT INTO admin_audit(id,actor,action,target,reason) VALUES(?,?,?,?,?)').bind(crypto.randomUUID(),String(actor.email),'delete-user-requested',target,JSON.stringify({reason:reason.trim(),confirmationEmail:expectedEmail})).run();
    try{
     await deleteAccountData(env,target);
     await session.remove(target);
     await env.metcue_db.batch([
      env.metcue_db.prepare('DELETE FROM admin_user_controls WHERE user_id=?').bind(target),
      env.metcue_db.prepare('INSERT INTO admin_audit(id,actor,action,target,reason) VALUES(?,?,?,?,?)').bind(crypto.randomUUID(),String(actor.email),'delete-user',target,reason.trim()),
     ]);
    }catch{
     return json({error:'Deletion is pending. Access is blocked once deletion begins. Retry this user from Pending deletions to finish removing all cloud data and the login.',deletionPending:true},503);
    }
    return json({success:true});
   }
   const isPhoto=action.includes('photo');
   const exists=isPhoto?await env.metcue_db.prepare("SELECT id FROM photos WHERE id=? AND purpose='portrait'").bind(target).first():await env.metcue_db.prepare('SELECT user_id FROM wallet_records WHERE user_id=? UNION SELECT id FROM users WHERE id=?').bind(target,target).first();
   if(!exists)return json({error:'Record unavailable.'},404);
   if(target===actor.sub)return json({error:'The owner account is protected.'},403);
   if(!isPhoto){const account=await env.metcue_db.prepare('SELECT email FROM users WHERE id=?').bind(target).first<{email:string}>();if(account?.email&&await administrator(account.email,env))return json({error:'Administrator accounts are protected.'},403);}
   const control=isPhoto?env.metcue_db.prepare(`INSERT INTO admin_photo_controls(photo_id,hidden,reason) VALUES(?,?,?) ON CONFLICT(photo_id) DO UPDATE SET hidden=excluded.hidden,reason=excluded.reason,updated_at=CURRENT_TIMESTAMP`).bind(target,action==='hide-photo'?1:0,reason.trim()):env.metcue_db.prepare(`INSERT INTO admin_user_controls(user_id,suspended,reason) VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET suspended=excluded.suspended,reason=excluded.reason,updated_at=CURRENT_TIMESTAMP`).bind(target,action==='suspend'?1:0,reason.trim());
   await env.metcue_db.batch([control,env.metcue_db.prepare('INSERT INTO admin_audit(id,actor,action,target,reason) VALUES(?,?,?,?,?)').bind(crypto.randomUUID(),String(actor.email),action,target,reason.trim())]);
   return json({success:true});
  }
  return json({error:'Not found.'},404);
 }catch(error){console.error(JSON.stringify({event:'admin_error',message:error instanceof Error?error.message:'Unknown'}));return json({error:'The request could not be completed. Please retry.'},500);}
}};}
export default createAdminHandler();
