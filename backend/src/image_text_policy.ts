// Supplements the model for explicit promotion patterns seen in the launch probes.
// This is narrow, English-language triage, not a comprehensive harm classifier.
export function policyTextCategories(value:string):string[]{
 const text=value.normalize('NFKC').replace(/[\u200B-\u200D\uFEFF]/g,'').toLowerCase();
 const clauses=text.split(/[.!?\n]+/);
 const rules:[string,RegExp][]=[
  ['policy/pornographic-promotion',/\b(?:visit|join|view|watch|buy|subscribe|sell|selling|access)\b.{0,100}\b(?:explicit porn(?:ographic)?(?: gallery)?|porn collection|pornographic (?:content|gallery))\b/],
  ['policy/pornographic-promotion',/\b(?:explicit pornographic|pornographic)\s+(?:gallery|content|collection)\b.{0,100}\b(?:subscribe|buy|join|access)\b/],
  ['policy/dangerous-challenge-promotion',/\b(?:dare|challenge|stunt)\b.{0,120}\b(?:dangerous|serious risk of injury|ignore safety)\b/],
  ['policy/dangerous-challenge-promotion',/\b(?:encourage|urge|challenge|dare)\b.{0,100}\b(?:hazardous|dangerous)\s+(?:stunts?|challenges?)\b/],
  ['policy/harmful-substance-promotion',/\b(?:misuse|abuse)\b.{0,80}\b(?:prescription|medicines|medication)\b.{0,80}\b(?:get high|intoxication|ignore.{0,20}warnings)\b/],
  ['policy/exploitation-promotion',/\b(?:confiscate|take away|seize)\b.{0,50}\b(?:passports?|travel documents)\b|\bforce\b.{0,70}\bwork\b.{0,40}\b(?:without pay|unpaid|no wages)\b/],
  ['policy/exploitation-promotion',/\bmake\b.{0,60}\bwork\b.{0,40}\b(?:without pay|unpaid|no wages)\b/],
  ['policy/illegal-weapons-promotion',/\b(?:sell|selling|buy|purchase|trade)\b.{0,70}\b(?:illegal|unlicensed)\b.{0,40}\b(?:guns|firearms|weapons)\b/],
 ];
 return [...new Set(rules.filter(([,pattern])=>clauses.some(clause=>[...clause.matchAll(new RegExp(pattern.source,'g'))].some(match=>!/(?:\bdo not|\bdon't|\bnever|\bavoid|\bstop|\breport|\bprevent|\breport (?:people|anyone) who)\s*$/.test(clause.slice(0,match.index))))).map(([name])=>name))];
}
