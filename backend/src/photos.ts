import {assertSafeImage} from './image_safety';
import { requireActiveAccount, requireVisiblePhoto } from './moderation';
import { isAccountDeleted } from './account_deletion';
import { ApiError, type JsonObject } from './records';

const MAX_BYTES = 512 * 1024;
export function photoType(bytes: Uint8Array): string {
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if ([137,80,78,71,13,10,26,10].every((v,i)=>bytes[i]===v)) return 'image/png';
  if (new TextDecoder().decode(bytes.slice(0,4)) === 'RIFF' && new TextDecoder().decode(bytes.slice(8,12)) === 'WEBP') return 'image/webp';
  throw new ApiError(400,'Choose a JPEG, PNG or WebP photo.');
}
interface PhotoRow { id:string;user_id:string;purpose:string;object_key:string;content_type:string; }
export async function uploadPhoto(request:Request,env:Env,userId:string,safety=assertSafeImage):Promise<string> {
  const purpose = new URL(request.url).searchParams.get('purpose');
  if (purpose !== 'portrait' && purpose !== 'connection') throw new ApiError(400,'Invalid photo purpose.');
  const reader=request.body?.getReader();
  if (!reader) throw new ApiError(400,'Photo is required.');
  const chunks:Uint8Array[]=[];let size=0;
  while(true) {
    const part=await reader.read();if(part.done)break;
    size+=part.value.length;
    if(size>MAX_BYTES){await reader.cancel();throw new ApiError(413,'Use a photo smaller than 512 KB.');}
    chunks.push(part.value);
  }
  if(!size)throw new ApiError(400,'Photo is empty.');
  const bytes=new Uint8Array(size);let offset=0;
  for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  const contentType=photoType(bytes);
  const marker=new TextDecoder('latin1').decode(bytes);
  if((contentType==='image/png'&&marker.includes('acTL'))||(contentType==='image/webp'&&marker.includes('ANIM')))throw new ApiError(400,'Choose a still photo rather than an animated image.');
  const count=await env.metcue_db.prepare('SELECT count(*) AS count FROM photos WHERE user_id=?').bind(userId).first<{count:number}>();
  if((count?.count??0)>=2000)throw new ApiError(429,'Photo storage limit reached.');
  await safety(env,userId,bytes,contentType);
  const id=crypto.randomUUID(),key=`${userId}/${id}`;
  await env.PHOTOS.put(key,bytes,{httpMetadata:{contentType}});
  try {
    await env.metcue_db.prepare('INSERT INTO photos(id,user_id,purpose,object_key,content_type) VALUES(?,?,?,?,?)')
      .bind(id,userId,purpose,key,contentType).run();
  } catch(error) {await env.PHOTOS.delete(key);throw error;}
  return `${purpose === 'portrait'?'portrait':'photo'}:${id}`;
}
export async function validatePhotoRef(env:Env,userId:string,kind:string,record:JsonObject) {
  const ref=String(record.avatarUrl||'');if(!ref)return;
  const match=/^(portrait|photo):([\w-]{36})$/.exec(ref);
  if(!match)throw new ApiError(400,'Upload this photo before syncing.');
  // A received portrait is an opaque shared capability; it may resolve later
  // when its owner syncs. Private photos must always belong to this user.
  if(kind==='connection'&&match[1]==='portrait')return;
  const row=await env.metcue_db.prepare('SELECT * FROM photos WHERE id=? AND user_id=?').bind(match[2],userId).first<PhotoRow>();
  if(!row || (kind==='card'&&row.purpose!=='portrait'))throw new ApiError(400,'This photo is unavailable for this card.');
}
export async function readPhoto(env:Env,id:string,headers:Record<string,string>,userId?:string,safety=assertSafeImage):Promise<Response> {
  const row=userId
    ?await env.metcue_db.prepare('SELECT * FROM photos WHERE id=? AND user_id=?').bind(id,userId).first<PhotoRow>()
    :await env.metcue_db.prepare("SELECT * FROM photos WHERE id=? AND purpose='portrait'").bind(id).first<PhotoRow>();
  if(!row || await isAccountDeleted(env,row.user_id))throw new ApiError(404,'Photo unavailable.');
  await requireVisiblePhoto(env,id);
  await requireActiveAccount(env,row.user_id);
  if(!userId) {
    const active=await env.metcue_db.prepare(`SELECT id FROM wallet_records WHERE user_id=? AND kind='card' AND deleted=0 AND json_extract(payload,'$.avatarUrl')=? LIMIT 1`)
      .bind(row.user_id,`portrait:${id}`).first();
    if(!active)throw new ApiError(404,'Photo unavailable.');
  }
  const photo=await env.PHOTOS.get(row.object_key);
  if(!photo)throw new ApiError(404,'Photo unavailable.');
  if(photo.size>MAX_BYTES)throw new ApiError(413,'Photo is too large.');
  const bytes=new Uint8Array(await new Response(photo.body).arrayBuffer());
  await safety(env,row.user_id,bytes,row.content_type);
  return new Response(bytes,{headers:{...headers,'Content-Type':row.content_type,'Content-Length':String(photo.size),
    'Content-Security-Policy':"default-src 'none'",'Cache-Control':'no-store'}});
}
