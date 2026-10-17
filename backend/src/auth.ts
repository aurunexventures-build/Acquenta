import { createRemoteJWKSet, jwtVerify } from 'jose';

const GOOGLE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);

export async function verifyAuth(request: Request, projectId: string): Promise<string> {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new Error("Missing or invalid Authorization header. Expected Bearer token.");
  }
  const token = authHeader.substring(7);
  try {
    const { payload } = await jwtVerify(token, GOOGLE_JWKS, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
    });
    if (!payload.sub) {
      throw new Error("Invalid token: sub claim missing.");
    }
    return payload.sub;
  } catch (err: any) {
    throw new Error(`Authentication failed: ${err.message}`);
  }
}
