// Company-wide operational metering. No user identifiers, prompts, text or audio are retained.
export interface AIMetrics {
  inputTokens?: number; outputTokens?: number; audioSeconds?: number; characters?: number;
  quota?: Record<string,string>; observedAt?: string;
}
const count=(value:unknown):number|undefined=>typeof value==='number'&&Number.isFinite(value)&&value>=0?value:undefined;
export function captureTokens(metrics:AIMetrics,result:unknown){
  if(!result||typeof result!=='object')return;
  const usage=(result as {usage?:Record<string,unknown>}).usage;
  if(!usage)return;
  metrics.inputTokens=count(usage.prompt_tokens);metrics.outputTokens=count(usage.completion_tokens);
}
export function captureQuota(metrics:AIMetrics,headers:Headers){
  const quota:Record<string,string>={};
  for(const key of ['limit-requests','remaining-requests','reset-requests','limit-tokens','remaining-tokens','reset-tokens']){
    const value=headers.get('x-ratelimit-'+key);
    if(value&&value.length<=80&&/^[\d.hmsuµ ]+$/.test(value))quota[key]=value;
  }
  if(Object.keys(quota).length){metrics.quota=quota;metrics.observedAt=new Date().toISOString();}
}
export async function meterAI<T>(env:Pick<Env,'metcue_db'>,provider:string,model:string,invoke:(metrics:AIMetrics)=>Promise<T>):Promise<T>{
  const started=Date.now(),startedAt=new Date(started).toISOString(),metrics:AIMetrics={};let succeeded=false;
  try{const result=await invoke(metrics);succeeded=true;return result;}
  finally{
    console.log(JSON.stringify({event:'ai_stage_timing',provider,model,durationMs:Date.now()-started,succeeded}));
    // A metering fault must never discard a successful AI result or replace a provider error.
    if(env.metcue_db)try{
      const tokenMeasured=metrics.inputTokens!==undefined&&metrics.outputTokens!==undefined;
      await env.metcue_db.prepare(`INSERT INTO ai_model_usage(day,provider,model,calls,succeeded,failed,input_tokens,output_tokens,token_responses,audio_seconds,audio_responses,characters,first_at,last_at)
        VALUES(?,?,?,1,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(day,provider,model) DO UPDATE SET
        calls=calls+1,succeeded=succeeded+excluded.succeeded,failed=failed+excluded.failed,
        input_tokens=input_tokens+excluded.input_tokens,output_tokens=output_tokens+excluded.output_tokens,token_responses=token_responses+excluded.token_responses,
        audio_seconds=audio_seconds+excluded.audio_seconds,audio_responses=audio_responses+excluded.audio_responses,characters=characters+excluded.characters,
        first_at=min(first_at,excluded.first_at),last_at=max(last_at,excluded.last_at)`)
        .bind(startedAt.slice(0,10),provider,model,succeeded?1:0,succeeded?0:1,metrics.inputTokens??0,metrics.outputTokens??0,tokenMeasured?1:0,metrics.audioSeconds??0,metrics.audioSeconds===undefined?0:1,metrics.characters??0,startedAt,new Date().toISOString()).run();
      if(metrics.quota)await env.metcue_db.prepare(`INSERT INTO ai_provider_quota(provider,model,observed_at,headers) VALUES(?,?,?,?)
        ON CONFLICT(provider,model) DO UPDATE SET observed_at=excluded.observed_at,headers=excluded.headers WHERE excluded.observed_at>=ai_provider_quota.observed_at`)
        .bind(provider,model,metrics.observedAt!,JSON.stringify(metrics.quota)).run();
    }catch{console.warn(JSON.stringify({event:'ai_metering_failed',provider,model}));}
  }
}
export async function runEmbeddings(env:Env,text:string[]){
  return meterAI(env,'cloudflare','@cf/baai/bge-small-en-v1.5',async metrics=>{
    const result=await env.AI.run('@cf/baai/bge-small-en-v1.5',{text});captureTokens(metrics,result);return result;
  });
}
