export const GOOGLE_VISION_ENDPOINT = "https://vision.googleapis.com/v1/images:annotate";
// Version also identifies our thresholds, so changes cannot reuse old approvals.
export const GOOGLE_IMAGE_MODEL = "google-vision-safesearch-ocr-policy-v2";
const likelihoods = ["VERY_UNLIKELY", "UNLIKELY", "POSSIBLE", "LIKELY", "VERY_LIKELY"];
type Verdict = {
  verdict: "passed" | "flagged" | "unavailable";
  categories: string[];
  model: string;
  extractedText?: string;
};

export async function callGoogleImageModeration(
  key: string | undefined,
  dataUrl: string,
  fetcher: typeof fetch = fetch,
): Promise<Verdict> {
  const unavailable = (reason: string): Verdict => ({
    verdict: "unavailable",
    categories: [reason],
    model: GOOGLE_IMAGE_MODEL,
  });
  if (!key) return unavailable("google-key-missing");
  const match = dataUrl.match(/^data:image\/(png|jpeg|webp);base64,([A-Za-z0-9+/]+={0,2})$/);
  if (!match || match[2]!.length > Math.ceil((5 * 1024 * 1024) / 3) * 4)
    return unavailable("invalid-image");
  const controller = new AbortController(),
    timer = setTimeout(() => controller.abort(), 12_000);
  try {
    const response = await fetcher(GOOGLE_VISION_ENDPOINT, {
      method: "POST",
      redirect: "manual",
      signal: controller.signal,
      headers: { "content-type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        requests: [{ image: { content: match[2] }, features: [{ type: "SAFE_SEARCH_DETECTION" }, { type: "TEXT_DETECTION" }] }],
      }),
    });
    if (!response.ok) {
      await response.body?.cancel();
      return unavailable(`google-api-${response.status}`);
    }
    const reader = response.body?.getReader();
    if (!reader) throw Error("Empty response");
    const chunks: Uint8Array[] = [];
    let length = 0;
    try {
      for (;;) {
        const next = await reader.read();
        if (next.done) break;
        length += next.value.length;
        if (length > 512_000) {
          await reader.cancel();
          throw Error("Response too large");
        }
        chunks.push(next.value);
      }
    } finally {
      reader.releaseLock();
    }
    const bytes = new Uint8Array(length);
    let at = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, at);
      at += chunk.length;
    }
    const data = JSON.parse(new TextDecoder().decode(bytes));
    const result = data.responses?.[0],
      scores = result?.safeSearchAnnotation;
    if (
      data.responses?.length !== 1 ||
      result.error ||
      !scores ||
      typeof scores !== "object" ||
      Array.isArray(scores)
    )
      throw Error("Missing verdict");
    // UNKNOWN, omitted fields and provider errors must never publish an image.
    for (const category of ["adult", "violence", "racy", "medical", "spoof"])
      if (!likelihoods.includes(scores[category])) throw Error("Incomplete verdict");
    // A successful annotation can omit OCR fields when no text is detected.
    // Reject malformed/oversized text instead of truncating unchecked content.
    if (result.textAnnotations !== undefined && !Array.isArray(result.textAnnotations))
      throw Error("Invalid OCR annotations");
    if (result.fullTextAnnotation !== undefined &&
        (!result.fullTextAnnotation || typeof result.fullTextAnnotation.text !== "string"))
      throw Error("Invalid OCR text");
    if (result.textAnnotations?.length && typeof result.textAnnotations[0]?.description !== "string")
      throw Error("Invalid OCR description");
    const extractedText = result.fullTextAnnotation?.text ?? result.textAnnotations?.[0]?.description ?? "";
    if (extractedText.length > 16_000) throw Error("OCR text too large");
    const categories = ["adult", "violence", "racy"]
      .filter((category) => likelihoods.indexOf(scores[category]) >= 2)
      .map((category) => `google-${category}:${String(scores[category]).toLowerCase()}`);
    return {
      verdict: categories.length ? "flagged" : "passed",
      categories,
      model: GOOGLE_IMAGE_MODEL,
      extractedText,
    };
  } catch {
    return unavailable("google-check-failed");
  } finally {
    clearTimeout(timer);
  }
}


export const MODERATION_ENDPOINT='https://api.openai.com/v1/moderations';
export const MODERATION_MODEL='omni-moderation-latest';
type Input={type:'text';text:string}|{type:'image_url';image_url:{url:string}};

export async function callFreeModeration(key:string|undefined,input:Input,fetcher:typeof fetch=fetch):Promise<Verdict>{
  if(!key)return {verdict:'unavailable',categories:['key-missing'],model:MODERATION_MODEL};
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),12000);
  try {
    const response=await fetcher(MODERATION_ENDPOINT,{method:'POST',redirect:'manual',signal:controller.signal,headers:{authorization:`Bearer ${key}`,'content-type':'application/json'},body:JSON.stringify({model:MODERATION_MODEL,input:[input]})});
    if(!response.ok){await response.body?.cancel();return {verdict:'unavailable',categories:[`api-${response.status}`],model:MODERATION_MODEL};}
    // Bounded reading; provider errors/response bodies never reach logs or the client.
    const reader=response.body?.getReader();if(!reader)throw Error('Empty response');
    const chunks:Uint8Array[]=[];let length=0;
    try{for(;;){const next=await reader.read();if(next.done)break;length+=next.value.length;if(length>64000){await reader.cancel();throw Error('Response too large');}chunks.push(next.value);}}finally{reader.releaseLock();}
    const bytes=new Uint8Array(length);let at=0;for(const part of chunks){bytes.set(part,at);at+=part.length;}
    const data=JSON.parse(new TextDecoder().decode(bytes)),result=data.results?.[0];
    if(data.results?.length!==1||typeof result?.flagged!=='boolean'||!result.categories||typeof result.categories!=='object'||Array.isArray(result.categories)||!Object.keys(result.categories).length||Object.values(result.categories).some(v=>typeof v!=='boolean'))throw Error('Invalid verdict');
    if(['sexual','self-harm','violence','hate','harassment'].some(name=>typeof result.categories[name]!=='boolean'))throw Error('Incomplete verdict');
    const categories=Object.keys(result.categories).filter(k=>result.categories[k]===true);
    return {verdict:result.flagged||categories.length?'flagged':'passed',categories,model:typeof data.model==='string'?data.model.slice(0,100):MODERATION_MODEL};
  }catch{return {verdict:'unavailable',categories:['check-failed'],model:MODERATION_MODEL};}finally{clearTimeout(timer);}
}
