import {ApiError} from './records';
export async function requireActiveAccount(env:Env,userId:string){
 const row=await env.metcue_db.prepare('SELECT suspended FROM admin_user_controls WHERE user_id=?').bind(userId).first<{suspended:number}>();
 if(row?.suspended)throw new ApiError(403,'Cloud access has been suspended. Contact aurunex.ventures@gmail.com for review.');
}
export async function requireVisiblePhoto(env:Env,id:string){
 const row=await env.metcue_db.prepare('SELECT hidden FROM admin_photo_controls WHERE photo_id=?').bind(id).first<{hidden:number}>();
 if(row?.hidden)throw new ApiError(404,'Photo unavailable.');
}

// Called only after the request's Firebase JWT has been verified.
export async function recordSyncedIdentity(request:Request,env:Env,userId:string){
 const token=request.headers.get('Authorization')?.slice(7).split('.')[1];if(!token)return;
 let identity;try{identity=JSON.parse(atob(token.replace(/-/g,'+').replace(/_/g,'/')));}catch{return;}
 if(identity.sub!==userId)return;
 const email=typeof identity.email==='string'?identity.email.slice(0,320):'';
 const name=typeof identity.name==='string'?identity.name.slice(0,200):'';
 await env.metcue_db.prepare(`INSERT INTO users(id,email,display_name) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET email=excluded.email,display_name=excluded.display_name,updated_at=CURRENT_TIMESTAMP`).bind(userId,email,name).run();
}
