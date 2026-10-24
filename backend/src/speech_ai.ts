import {meterAI,captureQuota} from './ai_metering';
import { ApiError, text, type JsonObject } from './records';
type SpeechEnv = Env & { GROQ_API_KEY?: string };
async function bytes(response: Response, limit: number): Promise<Uint8Array> {
  const reader=response.body?.getReader(); if(!reader) throw new Error('Empty audio');
  const parts: Uint8Array[]=[]; let size=0;
  while(true){const part=await reader.read();if(part.done)break;size+=part.value.length;
    if(size>limit){await reader.cancel();throw new Error('Audio too large');}parts.push(part.value);}
  const result=new Uint8Array(size);let offset=0;
  for(const part of parts){result.set(part,offset);offset+=part.length;}return result;
}
function encode(data: Uint8Array): string {
  let value='';for(let i=0;i<data.length;i+=8192)value+=String.fromCharCode(...data.subarray(i,i+8192));return btoa(value);
}
export async function speechAI(env: SpeechEnv, action: 'speak'|'transcribe', body: JsonObject) {
  if(!env.GROQ_API_KEY?.trim())throw new ApiError(503,'Online voice is unavailable. You can type your reply.');
  let payload: BodyInit, headers: Record<string,string>={Authorization:`Bearer ${env.GROQ_API_KEY.trim()}`};
  if(action==='speak'){
    const input=text(body.text,200);if(!input)throw new ApiError(400,'Add something to speak.');
    headers['Content-Type']='application/json';
    payload=JSON.stringify({model:'canopylabs/orpheus-v1-english',voice:'troy',input,response_format:'wav'});
  }else{
    const audio=text(body.audio,1000000);if(!audio||!/^[A-Za-z0-9+/]+={0,2}$/.test(audio))throw new ApiError(400,'Invalid recording.');
    let decoded: string;try{decoded=atob(audio);}catch{throw new ApiError(400,'Invalid recording.');}
    if(decoded.length<16)throw new ApiError(400,'Recording is empty.');
    const mimeType=body.mimeType==null?'audio/mp4':text(body.mimeType,80);
    if(!['audio/mp4','audio/wav'].includes(mimeType))throw new ApiError(400,'Unsupported recording format.');
    const form=new FormData();
    form.set('model','whisper-large-v3');
    form.set('file',new Blob([Uint8Array.from(decoded,c=>c.charCodeAt(0))],{type:mimeType}),mimeType==='audio/wav'?'reply.wav':'reply.m4a');
    form.set('response_format','json');form.set('temperature','0');
    // Auto-detect language, preserving Hindi/English speech rather than translating it.
    form.set('prompt','Acquenta, AuruNex. Transcribe the spoken words faithfully, including Indian English pronunciation.');
    payload=form;
  }
  return meterAI(env,'groq',action==='speak'?'canopylabs/orpheus-v1-english':'whisper-large-v3',async metrics=>{
  if(action==='speak')metrics.characters=text(body.text,200).length;
  try{
    const response=await fetch(`https://api.groq.com/openai/v1/audio/${action==='speak'?'speech':'transcriptions'}`,{
      method:'POST',headers,body:payload,signal:AbortSignal.timeout(25000)});
    captureQuota(metrics,response.headers);
    if(!response.ok){
      let code='unknown';
      try { const failure=JSON.parse(new TextDecoder().decode(await bytes(response,8192)));
        if(typeof failure.error?.code==='string')code=failure.error.code.replace(/[^a-zA-Z0-9_-]/g,'').slice(0,80);
      } catch { /* Log only a safe error code, never provider response text. */ }
      console.log(JSON.stringify({event:'speech_ai_error',action,status:response.status,code}));throw new Error('Speech unavailable');
    }
    const result=await bytes(response,action==='speak'?2000000:32000);
    if(action==='speak'){
      if(new TextDecoder().decode(result.subarray(0,4))!=='RIFF')throw new Error('Invalid speech audio');
      return {audio:encode(result),mimeType:'audio/wav'};
    }
    const parsed=JSON.parse(new TextDecoder().decode(result));
    if(typeof parsed.duration==='number'&&Number.isFinite(parsed.duration)&&parsed.duration>=0)metrics.audioSeconds=parsed.duration;
    const transcript=text(parsed.text,6000);if(!transcript)throw new Error('No words heard');
    return {text:transcript};
  }catch{throw new ApiError(503,action==='speak'?'Natural voice is temporarily unavailable. Continue by typing or retry.':'Could not transcribe that recording. Please try again or type your reply.');}
  });
}
