// Company-wide provider calls, not the separate per-user safety allowance.
export async function aiUsage(env:Env){
 const summary=await env.metcue_db.prepare(`SELECT coalesce(sum(CASE WHEN day=date('now') THEN calls ELSE 0 END),0) AS today,
  coalesce(sum(CASE WHEN day>=date('now','-6 days') THEN calls ELSE 0 END),0) AS week,
  coalesce(sum(CASE WHEN day>=date('now','start of month') THEN calls ELSE 0 END),0) AS month,
  coalesce(sum(calls),0) AS trackedTotal,min(first_at) AS trackingSince FROM ai_model_usage WHERE day<=date('now')`).first();
 const models=await env.metcue_db.prepare(`SELECT provider,model,sum(calls) AS calls,sum(succeeded) AS succeeded,sum(failed) AS failed,
  sum(input_tokens) AS input_tokens,sum(output_tokens) AS output_tokens,sum(token_responses) AS token_responses,
  sum(audio_seconds) AS audio_seconds,sum(audio_responses) AS audio_responses,sum(characters) AS characters,
  sum(CASE WHEN day=date('now') THEN calls ELSE 0 END) AS today,
  sum(CASE WHEN day=date('now') THEN input_tokens ELSE 0 END) AS today_input_tokens,
  sum(CASE WHEN day=date('now') THEN output_tokens ELSE 0 END) AS today_output_tokens,
  sum(CASE WHEN day=date('now') THEN token_responses ELSE 0 END) AS today_token_responses,
  sum(CASE WHEN day>=date('now','start of month') THEN calls ELSE 0 END) AS month,
  min(first_at) AS first_at,max(last_at) AS last_at FROM ai_model_usage WHERE day<=date('now') GROUP BY provider,model ORDER BY calls DESC,provider,model`).all();
 const quota=await env.metcue_db.prepare('SELECT provider,model,observed_at,headers FROM ai_provider_quota ORDER BY provider,model').all<{provider:string;model:string;observed_at:string;headers:string}>();
 const legacy=await env.metcue_db.prepare(`SELECT coalesce(sum(calls),0) AS requests FROM ai_usage WHERE user_id NOT LIKE 'form:%' AND day<=date('now')`).first();
 return {summary,models:models.results,quotas:quota.results.map(row=>({...row,headers:JSON.parse(row.headers)})),legacy,generatedAt:new Date().toISOString(),timezone:'UTC'};
}
