import {meterAI,captureQuota,captureTokens,type AIMetrics} from './ai_metering';
import { ApiError, type JsonObject } from './records';

type TextAIEnv = Env & { GROQ_API_KEY?: string };
export const GROQ_TEXT_MODEL = 'openai/gpt-oss-120b';

/** Shared server-only text provider. Embeddings continue to use Workers AI. */
export async function runTextAI(env: TextAIEnv, input: JsonObject, timeoutMs = 25000): Promise<{response: unknown}> {
  const groq=Boolean(env.GROQ_API_KEY?.trim());
  return meterAI(env,groq?'groq':'cloudflare',groq?GROQ_TEXT_MODEL:env.CUE_MODEL,metrics=>textAI(env,input,metrics,timeoutMs));
}
async function textAI(env:TextAIEnv,input:JsonObject,metrics:AIMetrics,timeoutMs:number):Promise<{response:unknown}>{
  if (!env.GROQ_API_KEY?.trim()) {
    const result = await env.AI.run(env.CUE_MODEL, input);
    captureTokens(metrics,result);
    if (!('response' in result)) throw new ApiError(503, 'AI is unavailable. Your original words are kept.');
    return {response: result.response};
  }
  const format = input.response_format as JsonObject | undefined;
  const responseFormat = format?.type === 'json_schema'
    ? {type: 'json_schema', json_schema: {name: 'acquenta_result', strict: true, schema: format.json_schema}}
    : {type: 'json_object'};
  try {
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {Authorization: `Bearer ${env.GROQ_API_KEY.trim()}`, 'Content-Type': 'application/json'},
      signal: AbortSignal.timeout(timeoutMs),
      body: JSON.stringify({model: GROQ_TEXT_MODEL, messages: input.messages,
        temperature: input.temperature ?? 0.1, reasoning_effort: 'low',
        max_completion_tokens: Math.min(4096, Math.max(512, Number(input.completion_tokens) || Math.max(2048, Number(input.max_tokens) || 2048))),
        response_format: responseFormat}),
    });
    captureQuota(metrics,response.headers);
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error('Provider unavailable');
    }
    const reader = response.body?.getReader();
    if (!reader) throw new Error('Empty provider response');
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      size += part.value.length;
      if (size > 131072) { await reader.cancel(); throw new Error('Provider response too large'); }
      chunks.push(part.value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    const data = JSON.parse(new TextDecoder().decode(bytes));
    captureTokens(metrics,data);
    const choice = data.choices?.[0];
    if (choice?.finish_reason !== 'stop' || typeof choice.message?.content !== 'string') throw new Error('Incomplete response');
    const parsed: unknown = JSON.parse(choice.message.content);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('Invalid response');
    // Token counts only: never log credentials, user prompts, or generated card details.
    console.log(JSON.stringify({event: 'text_ai_usage', provider: 'groq', model: GROQ_TEXT_MODEL,
      inputTokens: Number(data.usage?.prompt_tokens) || 0, outputTokens: Number(data.usage?.completion_tokens) || 0}));
    return {response: parsed};
  } catch {
    // No silent provider switch: preserve the user's words and let them retry.
    throw new ApiError(503, 'AI is temporarily unavailable. Your original words are kept. Please retry.');
  }
}
