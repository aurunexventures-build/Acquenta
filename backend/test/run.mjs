import { build } from 'esbuild';
import { spawnSync } from 'node:child_process';
await build({entryPoints:['src/index.ts'],bundle:true,platform:'node',format:'esm',outfile:'.test-build/worker.mjs'});
await build({entryPoints:['src/account_deletion.ts'],bundle:true,platform:'node',format:'esm',outfile:'.test-build/account-deletion.mjs'});
const result=spawnSync(process.execPath,['--test','test/wallet.test.mjs'],{stdio:'inherit'});
process.exitCode=result.status??1;
