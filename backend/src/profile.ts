import { ApiError, normalizeRecord, object, text, type JsonObject } from './records';

export function normalizeProfile(input: unknown): JsonObject {
  const v = object(input), firstName = text(v.firstName,100), lastName = text(v.lastName,100);
  if(!firstName) throw new ApiError(400,'Enter your first name.');
  if(!Array.isArray(v.emails) || v.emails.length>5) throw new ApiError(400,'Use up to five contact email addresses.');
  const emails = v.emails.map(value=>text(value,320));
  if(emails.some(email=>! /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) ||
      new Set(emails.map(email=>email.toLowerCase())).size!==emails.length) {
    throw new ApiError(400,'Check your contact email addresses and remove duplicates.');
  }
  // Reuse the wallet's bounded link, timestamp and future-clock validation.
  const bounded = normalizeRecord({id:'about-me',fullName:[firstName,lastName].filter(Boolean).join(' '),
    links:v.links,updatedAt:v.updatedAt,createdAt:v.updatedAt},'card');
  return {firstName,lastName,phone:text(v.phone,100),role:text(v.role,200),company:text(v.company,200),
    intro:text(v.intro,300),emails,links:bounded.links,updatedAt:bounded.updatedAt};
}

export async function getProfile(env: Env, userId: string): Promise<JsonObject|null> {
  const row = await env.metcue_db.prepare('SELECT payload FROM account_profiles WHERE user_id=?')
    .bind(userId).first<{payload:string}>();
  return row ? object(JSON.parse(row.payload)) : null;
}

export async function saveProfile(env: Env,userId: string,input: unknown): Promise<JsonObject> {
  const profile = normalizeProfile(input);
  await env.metcue_db.prepare(`INSERT INTO account_profiles(user_id,payload,version) VALUES(?,?,?)
    ON CONFLICT(user_id) DO UPDATE SET payload=excluded.payload,version=excluded.version
    WHERE excluded.version>account_profiles.version`)
    .bind(userId,JSON.stringify(profile),Date.parse(String(profile.updatedAt))).run();
  return (await getProfile(env,userId))!;
}
