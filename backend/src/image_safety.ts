import {policyTextCategories} from './image_text_policy';
import {ApiError} from './records';
import {callFreeModeration,callGoogleImageModeration,GOOGLE_IMAGE_MODEL} from './image_safety_providers';

type SafetyEnv=Env & {OPENAI_API_KEY?:string;GOOGLE_VISION_API_KEY?:string};
const DAY=86400000;
const POLICY='acquenta-image-safety-v1';
function dataUrl(bytes:Uint8Array,mime:string) {
 const pieces:string[]=[];
 for(let at=0;at<bytes.length;at+=8192)pieces.push(String.fromCharCode(...bytes.subarray(at,at+8192)));
 return `data:${mime};base64,${btoa(pieces.join(''))}`;
}
/** Rejections keep previous content and the account intact. No rejected image bytes are stored. */
export async function assertSafeImage(env:SafetyEnv,userId:string,bytes:Uint8Array,mime:string,fetcher:typeof fetch=fetch) {
 const key=env.GOOGLE_VISION_API_KEY;
 if(!key?.trim())throw new ApiError(503,'Photo safety checks are unavailable. Please try again later.');
 const model=GOOGLE_IMAGE_MODEL;
 const hash=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(POLICY+model+dataUrl(bytes,mime)));
 const fingerprint=Array.from(new Uint8Array(hash),b=>b.toString(16).padStart(2,'0')).join('');
 const now=Date.now(),day=Math.floor(now/DAY),month=new Date(now).toISOString().slice(0,7);
 const previous=await env.metcue_db.prepare('SELECT verdict,checked_at FROM image_safety_checks WHERE user_id=? AND fingerprint=?').bind(userId,fingerprint).first<{verdict:string;checked_at:number}>();
 if(previous&&previous.checked_at>now-(previous.verdict==='unavailable'?60000:DAY)) {
  if(previous.verdict==='passed')return;
  throw new ApiError(previous.verdict==='flagged'?422:503,previous.verdict==='flagged'?'This photo could not pass our safety check. Please choose another image.':'Photo safety checks are unavailable. Please try again later.');
 }
 // Atomic reservation bounds provider calls, including concurrent requests and failed checks.
 const reserved=await env.metcue_db.prepare(`INSERT INTO image_safety_usage(month,day,user_id,calls)
 SELECT ?,?,?,1 WHERE (SELECT coalesce(sum(calls),0) FROM image_safety_usage WHERE month=?)<100
 AND (SELECT coalesce(sum(calls),0) FROM image_safety_usage WHERE day=?)<200
 AND (SELECT coalesce(sum(calls),0) FROM image_safety_usage WHERE day=? AND user_id=?)<10
 ON CONFLICT(month,day,user_id) DO UPDATE SET calls=calls+1 WHERE calls<10
 AND (SELECT coalesce(sum(calls),0) FROM image_safety_usage WHERE month=?)<100
 AND (SELECT coalesce(sum(calls),0) FROM image_safety_usage WHERE day=?)<200 RETURNING calls`)
 .bind(month,day,userId,month,day,day,userId,month,day).first();
 if(!reserved)throw new ApiError(429,'Photo safety check limit reached. Please try again later.');
 const url=dataUrl(bytes,mime);
 let result=await callGoogleImageModeration(key,url,fetcher);
 // Google SafeSearch alone does not judge abuse written inside a picture.
 const extractedText=result.extractedText;
 if(result.verdict==='passed'&&typeof extractedText==='string'&&extractedText.trim()) {
  const local=policyTextCategories(extractedText.replace(/\r?\n/g,' '));
  if(local.length)result={...result,verdict:'flagged',categories:local.map(c=>'ocr/'+c)};
  for(let at=0;result.verdict==='passed'&&at<extractedText.length;at+=8000) {
   const checked=await callFreeModeration(env.OPENAI_API_KEY,{type:'text',text:extractedText.slice(Math.max(0,at-500),at+8000)},fetcher);
   if(checked.verdict!=='passed') {result={...checked,categories:checked.categories.map(c=>'ocr/'+c)};break;}
  }
 }
 await env.metcue_db.prepare(`INSERT INTO image_safety_checks(user_id,fingerprint,verdict,categories,model,checked_at) VALUES(?,?,?,?,?,?)
 ON CONFLICT(user_id,fingerprint) DO UPDATE SET verdict=excluded.verdict,categories=excluded.categories,model=excluded.model,checked_at=excluded.checked_at`)
 .bind(userId,fingerprint,result.verdict,JSON.stringify(result.categories),model,now).run();
 if(result.verdict!=='passed')throw new ApiError(result.verdict==='flagged'?422:503,result.verdict==='flagged'?'This photo could not pass our safety check. Please choose another image.':'Photo safety checks are unavailable. Please try again later.');
}
