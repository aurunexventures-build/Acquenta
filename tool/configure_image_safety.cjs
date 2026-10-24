const fs=require('node:fs');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const google=process.env.ACQUENTA_VISION_KEY?.trim();
if(!google||!/^[A-Za-z0-9_-]{20,200}$/.test(google)){console.error('No valid key entered. Nothing changed.');process.exit(1);}
// Reuse the existing text-only moderation credential; never display either secret.
const source=path.resolve(root,'../Landing Page Builder/landing-page-builder-cloudflare/.dev.vars');
let openai;
try {const line=fs.readFileSync(source,'utf8').match(/^OPENAI_API_KEY\s*=\s*(.+)$/m)?.[1]?.trim();openai=line?.replace(/^['"]|['"]$/g,'');}catch{}
if(!openai){console.error('The existing text moderation credential is unavailable. Tell Codex; do not paste keys into chat.');process.exit(1);}
const result=spawnSync(process.execPath,[path.join(root,'backend/node_modules/wrangler/bin/wrangler.js'),'secret','bulk','--config',path.join(root,'wrangler.jsonc')],{cwd:root,input:JSON.stringify({GOOGLE_VISION_API_KEY:google,OPENAI_API_KEY:openai}),encoding:'utf8'});
if(result.status!==0){console.error('Could not store the secrets. Sign into Cloudflare with Wrangler, then retry. No key was printed.');process.exit(1);}
console.log('Google Vision and text moderation credentials stored for Acquenta. Tell Codex to activate and verify the update.');
