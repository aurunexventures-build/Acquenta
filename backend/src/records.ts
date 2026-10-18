export type JsonObject = Record<string, unknown>;
export class ApiError extends Error {
  constructor(public status: number, message: string) { super(message); }
}
export function object(value: unknown): JsonObject {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new ApiError(400, 'Expected an object.');
  return value as JsonObject;
}
export function text(value: unknown, max = 2000): string {
  if (value == null) return '';
  if (typeof value !== 'string' || value.length > max) throw new ApiError(400, 'Text is invalid or too long.');
  return value.trim();
}
export function list(value: unknown): string[] {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > 30) throw new ApiError(400, 'Too many cues.');
  return [...new Set(value.map(v => text(v, 200)).filter(Boolean))];
}
export function identifier(value: unknown): string {
  const id = text(value, 150);
  if (!/^[\w-]{1,150}$/.test(id)) throw new ApiError(400, 'Invalid identifier.');
  return id;
}
export function date(value: unknown): string {
  const s = text(value, 50);
  if (!s || !Number.isFinite(Date.parse(s))) throw new ApiError(400, 'Invalid date.');
  return new Date(s).toISOString();
}
export function cueConversation(value:unknown):JsonObject[] {
  if(value==null)return [];
  if(!Array.isArray(value)||value.length>3)throw new ApiError(400,'A memory conversation supports up to three answers.');
  return value.map(raw=>{const item=object(raw);const question=text(item.question,2000),answer=text(item.answer,2000);
    if(!question||!answer)throw new ApiError(400,'Both question and answer are required.');
    return {question,answer};});
}
export function normalizeRecord(input: unknown, kind: string): JsonObject {
  const v = object(input);
  const result: JsonObject = { id: identifier(v.id), fullName: text(v.fullName, 200) };
  if (!result.fullName) throw new ApiError(400, 'Name is required.');
  for (const key of ['role', 'company', 'headline', 'email', 'phone', 'avatarUrl']) result[key] = text(v[key]);
  result.techStack = list(v.techStack);
  const links = v.links ?? [];
  if (!Array.isArray(links) || links.length > 20) throw new ApiError(400, 'Too many links.');
  result.links = links.map(raw => {
    const link = object(raw);
    const url = text(link.url, 2000);
    if (!/^(https?:\/\/|mailto:|tel:)/i.test(url)) throw new ApiError(400, 'Unsupported link.');
    return { id: identifier(link.id), title: text(link.title, 100), type: text(link.type, 30), url };
  });
  result.updatedAt = date(v.updatedAt ?? v.savedAt ?? v.createdAt);
  if (Date.parse(String(result.updatedAt)) > Date.now() + 300000) throw new ApiError(400, 'Device clock is too far ahead.');
  if (kind === 'connection') {
    const event = object(v.eventContext);
    result.eventContext = { eventName: text(event.eventName, 300), location: text(event.location, 300),
      date: date(event.date), notes: text(event.notes, 6000), tags: list(event.tags) };
    for (const key of ['futureSelfNote', 'distinctiveMemory', 'microContext', 'rawCue']) result[key] = text(v[key], 6000);
    for (const key of ['vibeTags', 'callWhen']) result[key] = list(v[key]);
    result.cueConversation=cueConversation(v.cueConversation);
    if (new TextEncoder().encode(JSON.stringify(result.interactions)).byteLength > 200000) throw new ApiError(400, 'History exceeds 200 KB.');
    result.savedAt = date(v.savedAt);
    result.isFavorite = v.isFavorite === true;
    result.followUpAt = v.followUpAt == null ? null : date(v.followUpAt);
    result.followUpNote = text(v.followUpNote, 1000);
    result.followUpCompleted = v.followUpCompleted === true;
    const interactions = v.interactions ?? [];
    if (!Array.isArray(interactions) || interactions.length > 100) throw new ApiError(400, 'History supports up to 100 entries.');
    const seen = new Set<string>();
    result.interactions = interactions.map(raw => {
      const entry = object(raw), id = identifier(entry.id), kind = text(entry.kind, 20) || 'note';
      if (seen.has(id) || !['note', 'cue'].includes(kind)) throw new ApiError(400, 'Invalid history entry.');
      seen.add(id);
      const value = text(entry.text, kind === 'cue' ? 26000 : 2000);
      if (!value) throw new ApiError(400, 'History notes cannot be empty.');
      return {id, at: date(entry.at), text: value, kind};
    });
  } else {
    for (const key of ['title', 'category', 'location', 'bio', 'themeColorHex']) result[key] = text(v[key]);
    result.createdAt = date(v.createdAt);
    result.isDefault = v.isDefault === true;
  }
  return result;
}
export function searchText(record: JsonObject): string {
  const e = object(record.eventContext);
  return [record.fullName, record.role, record.company, record.headline, ...(record.techStack as string[] ?? []),
    e.eventName, e.location, e.date, e.notes, ...(e.tags as string[] ?? []), record.rawCue,
    record.futureSelfNote, record.distinctiveMemory, record.microContext, record.followUpNote,
    ...((record.interactions as JsonObject[] | undefined) ?? []).map(entry => entry.text),
    ...((record.cueConversation as JsonObject[]|undefined)??[]).map(turn=>`${turn.question}: ${turn.answer}`),
    ...(record.vibeTags as string[] ?? []), ...(record.callWhen as string[] ?? [])].filter(Boolean).join(' | ');
}
export async function vectorId(userId: string, id: string): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${userId}:${id}`));
  return [...new Uint8Array(hash)].map(v => v.toString(16).padStart(2, '0')).join('');
}
export function html(value: unknown): string {
  return String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]!));
}
