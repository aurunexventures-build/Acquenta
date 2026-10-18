import {importPKCS8, SignJWT} from 'jose';

type AdminConfig = {FIREBASE_PROJECT_ID: string; FIREBASE_ADMIN_SERVICE_ACCOUNT?: string};
export type FirebaseDeletionSession = {
  lookup(uid: string): Promise<{email?: string} | null>;
  remove(uid: string): Promise<void>;
};

export async function firebaseDeletionSession(env: AdminConfig): Promise<FirebaseDeletionSession> {
  if (!env.FIREBASE_ADMIN_SERVICE_ACCOUNT) throw new Error('Deletion credentials unavailable');
  const account = JSON.parse(env.FIREBASE_ADMIN_SERVICE_ACCOUNT) as {
    project_id: string; client_email: string; private_key: string;
  };
  if (account.project_id !== env.FIREBASE_PROJECT_ID || !account.client_email || !account.private_key) {
    throw new Error('Invalid deletion credentials');
  }
  const assertion = await new SignJWT({scope: 'https://www.googleapis.com/auth/identitytoolkit'})
    .setProtectedHeader({alg: 'RS256'})
    .setIssuer(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt().setExpirationTime('5m')
    .sign(await importPKCS8(account.private_key, 'RS256'));
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion}),
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new Error('Deletion authorization unavailable');
  const token = await response.json() as {access_token?: string};
  if (!token.access_token) throw new Error('Deletion authorization unavailable');
  const endpoint = `https://identitytoolkit.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/accounts`;
  async function call(method: string, body: object) {
    const result = await fetch(`${endpoint}:${method}`, {
      method: 'POST',
      headers: {Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json'},
      body: JSON.stringify(body), signal: AbortSignal.timeout(20000),
    });
    const data = await result.json() as {users?: {localId: string; email?: string}[]; error?: {message?: string}};
    if (!result.ok && data.error?.message !== 'USER_NOT_FOUND') throw new Error('Firebase deletion request failed');
    return data;
  }
  return {
    async lookup(uid) {
      const data = await call('lookup', {localId: [uid]});
      return data.users?.find(user => user.localId === uid) ?? null;
    },
    async remove(uid) { await call('delete', {localId: uid}); },
  };
}
