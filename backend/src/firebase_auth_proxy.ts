/** Firebase's supported same-origin sign-in helper proxy. */
export async function proxyFirebaseAuth(request: Request): Promise<Response> {
  const url = new URL(request.url);
  if (!url.pathname.startsWith('/__/auth/')) return new Response('Not found', {status:404});
  if (!['GET','POST'].includes(request.method)) {
    return new Response('Method not allowed', {status:405, headers:{Allow:'GET, POST'}});
  }
  // Fixed upstream: query parameters can never select another server.
  url.protocol = 'https:';
  url.hostname = 'metcue09.firebaseapp.com';
  url.port = '';
  const forwarded = new Request(url, request);
  forwarded.headers.delete('host');
  forwarded.headers.delete('authorization');
  forwarded.headers.delete('cookie');
  const upstream = await fetch(new Request(forwarded, {redirect:'manual'}));
  const responseHeaders = new Headers(upstream.headers);
  responseHeaders.set('Cache-Control','no-store');
  return new Response(upstream.body, {
    status:upstream.status,
    statusText:upstream.statusText,
    headers:responseHeaders,
  });
}
