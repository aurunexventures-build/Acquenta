import { decodeJwt } from 'jose';
import { ApiError, vectorId } from './records';

// Call only after verifyAuth has verified the token signature, issuer and audience.
export function requireRecentAuthentication(request: Request) {
  const token = request.headers.get('Authorization')?.slice(7) ?? '';
  const at = decodeJwt(token).auth_time;
  const now = Date.now()/1000;
  if (typeof at !== 'number' || at > now+30 || now-at > 300) {
    throw new ApiError(401,'Please confirm your sign-in again before deleting your account.');
  }
}

export async function deleteFirebaseIdentity(request: Request, env: {FIREBASE_API_KEY: string}) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${env.FIREBASE_API_KEY}`, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body:JSON.stringify({idToken:request.headers.get('Authorization')!.slice(7)}),
    signal:AbortSignal.timeout(20000),
  });
  const data = await response.json() as {error?:{message?:string}};
  if (!response.ok && data.error?.message !== 'USER_NOT_FOUND') {
    throw new ApiError(503,'Your cloud wallet is removed, but account deletion could not finish. Please retry Delete account.');
  }
}

export async function isAccountDeleted(env: Env, userId: string) {
  return !!await env.metcue_db.prepare('SELECT user_id FROM account_deletions WHERE user_id=?').bind(userId).first();
}

export async function deleteAccountData(env: Pick<Env, 'metcue_db' | 'VECTORIZE' | 'PHOTOS'>, userId: string) {
  // Marker and SQL triggers block concurrent writes, including from older clients.
  await env.metcue_db.prepare('INSERT OR IGNORE INTO account_deletions(user_id) VALUES(?)').bind(userId).run();
  const records = await env.metcue_db.prepare("SELECT id FROM wallet_records WHERE user_id=? AND kind='connection'").bind(userId).all<{id:string}>();
  const legacy = await env.metcue_db.prepare('SELECT id,embedding_id FROM saved_connections WHERE user_id=?').bind(userId).all<{id:string;embedding_id:string|null}>();
  const vectors = [...new Set([
    ...await Promise.all([...records.results,...legacy.results].map(row=>vectorId(userId,row.id))),
    ...legacy.results.map(row=>row.embedding_id).filter((id):id is string=>!!id),
  ])];
  for (let i=0;i<vectors.length;i+=100) await env.VECTORIZE.deleteByIds(vectors.slice(i,i+100));
  const photos = await env.metcue_db.prepare('SELECT object_key FROM photos WHERE user_id=?').bind(userId).all<{object_key:string}>();
  // Retain metadata until external deletion succeeds, so retries can find every object.
  for (let i=0;i<photos.results.length;i+=100) {
    await env.PHOTOS.delete(photos.results.slice(i,i+100).map(row=>row.object_key));
  }
  await env.metcue_db.prepare('DELETE FROM admin_photo_controls WHERE photo_id IN (SELECT id FROM photos WHERE user_id=?)').bind(userId).run();
  await env.metcue_db.prepare('DELETE FROM admin_user_controls WHERE user_id=?').bind(userId).run();
  for (const table of ['photos','card_shares','wallet_records','saved_connections','contact_cards','ai_usage','account_profiles']) {
    await env.metcue_db.prepare(`DELETE FROM ${table} WHERE user_id=?`).bind(userId).run();
  }
  await env.metcue_db.prepare('DELETE FROM users WHERE id=?').bind(userId).run();
}
