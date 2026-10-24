import {ApiError,type JsonObject} from './records';
import {hasProfanity} from './profanity';
import {policyTextCategories} from './image_text_policy';
type SafetyEnv=Env & {GOOGLE_TEXT_MODERATION_API_KEY?:string};
const DAY=86400000, POLICY='acquenta-text-google-v1';
export function cardText(value:JsonObject):string {
 const fields=['fullName','firstName','lastName','role','company','headline','bio','location','intro'].flatMap(key=>typeof value[key]==='string'?[String(value[key])]:[]);
 fields.push(...(Array.isArray(value.techStack)?value.techStack.filter((v):v is string=>typeof v==='string'):[]));
 for(const link of Array.isArray(value.links)?value.links:[])if(link&&typeof link==='object'&&typeof (link as JsonObject).title==='string')fields.push(String((link as JsonObject).title));
 return fields.filter(Boolean).join('\n');
}
export async function googleTextVerdict(key:string,text:string,fetcher:typeof fetch=fetch):Promise<'passed'|'flagged'|'unavailable'> {
 const timer=new AbortController(), timeout=setTimeout(()=>timer.abort(),10000);
 try {
  const response=await fetcher('https://language.googleapis.com/v1/documents:moderateText',{method:'POST',redirect:'manual',signal:timer.signal,headers:{'content-type':'application/json','x-goog-api-key':key},body:JSON.stringify({document:{type:'PLAIN_TEXT',content:text}})});
  if(!response.ok){await response.body?.cancel();return 'unavailable';}
  const reader=response.body?.getReader();if(!reader)return 'unavailable';
  const chunks:Uint8Array[]=[];let size=0;
  try{for(;;){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>64000){await reader.cancel();return 'unavailable';}chunks.push(part.value);}}finally{reader.releaseLock();}
  const bytes=new Uint8Array(size);let at=0;for(const part of chunks){bytes.set(part,at);at+=part.length;}
  const result=JSON.parse(new TextDecoder().decode(bytes));
  if(!Array.isArray(result.moderationCategories))return 'unavailable';
  const thresholds:Record<string,number>={Toxic:.75,Derogatory:.7,Violent:.85,Sexual:.8,Insult:.75,Profanity:.5};
  const scores=new Map<string,number>();
  for(const item of result.moderationCategories) {
   if(!item||typeof item.name!=='string'||typeof item.confidence!=='number'||!Number.isFinite(item.confidence)||item.confidence<0||item.confidence>1||scores.has(item.name))return 'unavailable';
   scores.set(item.name,item.confidence);
  }
  if(Object.keys(thresholds).some(name=>!scores.has(name)))return 'unavailable';
  return Object.entries(thresholds).some(([name,threshold])=>scores.get(name)!>=threshold)?'flagged':'passed';
 }catch{return 'unavailable';}finally{clearTimeout(timeout);}
}
export async function assertSafeText(env:SafetyEnv,userId:string,value:string,fetcher:typeof fetch=fetch) {
 const content=value.trim();if(!content)return;
 const denied='Please remove profanity or abusive language before saving or sharing.';
 if(hasProfanity(content)||policyTextCategories(content).length)throw new ApiError(422,denied);
 if(content.length>24000)throw new ApiError(400,'Please shorten this card text before saving.');
 const key=env.GOOGLE_TEXT_MODERATION_API_KEY;
 if(!key)throw new ApiError(503,'Text safety checks are unavailable. Your previous content is unchanged.');
 const fingerprint=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(POLICY+content))),b=>b.toString(16).padStart(2,'0')).join('');
 const now=Date.now(),month=new Date(now).toISOString().slice(0,7),day=Math.floor(now/DAY);
 const cached=await env.metcue_db.prepare('SELECT verdict,checked_at FROM text_safety_checks WHERE user_id=? AND fingerprint=?').bind(userId,fingerprint).first<{verdict:string;checked_at:number}>();
 if(cached&&cached.checked_at>now-(cached.verdict==='unavailable'?60000:DAY)) {
  if(cached.verdict==='passed')return;
  throw new ApiError(cached.verdict==='flagged'?422:503,cached.verdict==='flagged'?denied:'Text safety checks are unavailable. Please try again later.');
 }
 const parts:string[]=[];
 for(let at=0;at<content.length;at+=7000)parts.push(content.slice(Math.max(0,at-500),at+7000));
 const units=parts.reduce((sum,part)=>sum+Math.ceil(Array.from(part).length/100),0);
 const reserved=await env.metcue_db.prepare(`INSERT INTO text_safety_usage(month,day,user_id,calls,units)
 SELECT ?,?,?,1,? WHERE (SELECT coalesce(sum(units),0) FROM text_safety_usage WHERE month=?)+?<=5000
 AND (SELECT coalesce(sum(calls),0) FROM text_safety_usage WHERE day=? AND user_id=?)<100
 ON CONFLICT(month,day,user_id) DO UPDATE SET calls=calls+1,units=units+excluded.units WHERE calls<100
 AND (SELECT coalesce(sum(units),0) FROM text_safety_usage WHERE month=?)+excluded.units<=5000 RETURNING calls`)
 .bind(month,day,userId,units,month,units,day,userId,month).first();
 if(!reserved)throw new ApiError(429,'Text safety check limit reached. Please try again later.');
 let verdict:'passed'|'flagged'|'unavailable'='passed';
 for(const part of parts){verdict=await googleTextVerdict(key,part,fetcher);if(verdict!=='passed')break;}
 await env.metcue_db.prepare(`INSERT INTO text_safety_checks(user_id,fingerprint,verdict,checked_at) VALUES(?,?,?,?) ON CONFLICT(user_id,fingerprint) DO UPDATE SET verdict=excluded.verdict,checked_at=excluded.checked_at`).bind(userId,fingerprint,verdict,now).run();
 if(verdict!=='passed')throw new ApiError(verdict==='flagged'?422:503,verdict==='flagged'?denied:'Text safety checks are unavailable. Your previous content is unchanged.');
}
