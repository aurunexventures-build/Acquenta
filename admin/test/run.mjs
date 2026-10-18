import {fileURLToPath} from 'node:url';
process.chdir(fileURLToPath(new URL('../../',import.meta.url)));
import {build} from '../../backend/node_modules/esbuild/lib/main.js';
import {spawnSync} from 'node:child_process';
await build({absWorkingDir:process.cwd(),entryPoints:['admin/src/index.ts'],bundle:true,platform:'node',format:'esm',packages:'external',outfile:'admin/.test-build/admin.mjs'});
await build({absWorkingDir:process.cwd(),entryPoints:['admin/src/firebase_admin.ts'],bundle:true,platform:'node',format:'esm',packages:'external',outfile:'admin/.test-build/firebase-admin.mjs'});
const result=spawnSync(process.execPath,['--test','admin/test/admin.test.mjs'],{stdio:'inherit'});process.exitCode=result.status??1;
