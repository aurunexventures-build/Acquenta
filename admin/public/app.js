import {initializeApp} from 'https://www.gstatic.com/firebasejs/12.4.0/firebase-app.js';
import {getAuth,GoogleAuthProvider,signInWithPopup,signInWithEmailAndPassword,sendPasswordResetEmail,onAuthStateChanged,signOut,setPersistence,inMemoryPersistence,reauthenticateWithPopup,reauthenticateWithCredential,EmailAuthProvider} from 'https://www.gstatic.com/firebasejs/12.4.0/firebase-auth.js';
const app=initializeApp({apiKey:'AIzaSyBEcRA7IsRayBe6PwkLxXxLqOeaDgWa20U',authDomain:'metcue09.firebaseapp.com',projectId:'metcue09',appId:'1:1084823977938:web:51c6a4a15a82b9c508120b'});
const auth=getAuth(app);await setPersistence(auth,inMemoryPersistence);
const $=id=>document.getElementById(id);let currentView='overview',usersOffset=0,photosOffset=0,pending=null,blobs=[],ownerUid='',isOwner=false,authVersion=0;
const status=message=>{$('status').textContent=message;};
const el=(tag,text,className)=>{const node=document.createElement(tag);if(text!==undefined&&text!==null)node.textContent=text;if(className)node.className=className;return node;};
const time=value=>value?new Date(typeof value==='number'?value:value.replace(' ','T')+'Z').toLocaleString(): 'No sync recorded';
async function api(path,body){if(!auth.currentUser)throw new Error('Please sign in.');const token=await auth.currentUser.getIdToken();const requestUser=auth.currentUser;const response=await fetch(path,{headers:{Authorization:`Bearer ${token}`,...(body?{'Content-Type':'application/json'}:{})},...(body?{method:'POST',body:JSON.stringify(body)}:{})});if(auth.currentUser!==requestUser)throw new Error('Session ended.');if(!response.ok){let message='Request failed.';try{message=(await response.json()).error||message;}catch{}throw new Error(message);}return response;}
const data=async(path,body)=>(await api(path,body)).json();
function empty(parent,message){parent.replaceChildren(el('div',message,'empty'));}
function actionButton(action,target,title){const button=el('button',title,'action');button.onclick=()=>{pending={action,target};$('action-title').textContent=title;$('action-info').textContent=action==='suspend'?'Cloud sync, AI, public cards and photos will be blocked for this user. Data already downloaded to devices cannot be recalled.':action==='hide-photo'?'This portrait will no longer be served by Acquenta. Previously downloaded copies cannot be recalled.': 'Restore access to this account or portrait.';$('reason').value='';$('moderate-dialog').showModal();};return button;}
function auditReason(value){try{return JSON.parse(value).reason||value;}catch{return value;}}
function renderAudit(parent,rows){if(!rows.length){empty(parent,'No moderation actions yet.');return;}parent.replaceChildren();for(const row of rows){const item=el('article',null,'audit-item');item.append(el('strong',row.action.replaceAll('-',' ')),el('p',auditReason(row.reason)),el('p',`${row.actor} · ${time(row.created_at)}`),el('div',row.target,'uid'));parent.append(item);}}
async function overview(){const [summary,audit]=await Promise.all([data('/api/overview'),data('/api/audit')]);$('stats').replaceChildren();for(const [label,key]of [['Synced users','users'],['Identity cards','cards'],['Uploaded portraits','portraits'],['Suspended users','suspended'],['Hidden portraits','hidden'],['AI requests today','aiToday']]){const tile=el('article',null,'stat');tile.append(el('small',label),el('strong',Number(summary[key]||0).toLocaleString()));$('stats').append(tile);}renderAudit($('recent'),audit.slice(0,4));}
async function users(){await pendingDeletions();const result=await data(`/api/users?q=${encodeURIComponent($('search').value)}&offset=${usersOffset}`);const list=$('user-list');list.replaceChildren();if(!result.users.length)empty(list,'No synced users found.');for(const user of result.users){const item=el('article',null,'user'),details=el('div');details.append(el('h3',user.display_name||user.card_name||'Acquenta user'),el('div',user.suspended?'Suspended':'Active',`pill ${user.suspended?'flag':''}`),el('p',user.email||'Account email not yet synced'),el('p',`${user.cards} cards · ${user.connections} connections · Last sync: ${time(user.last_sync)}`),el('div',user.user_id,'uid'));if(user.reason)details.append(el('p',`Moderation note: ${user.reason}`));const actions=el('div',null,'user-actions');if(!user.is_admin)actions.append(actionButton(user.suspended?'restore-user':'suspend',user.user_id,user.suspended?'Restore cloud access':'Suspend cloud access'));if(user.is_admin){details.append(el('div','Admin account · Cannot be deleted','pill'));actions.append(el('span','Protected administrator account'));}else if(user.email&&isOwner){actions.append(deleteUserButton(user.user_id,user.email));}else{actions.append(el('span','Email unavailable · deletion disabled'));}item.append(details,actions);list.append(item);}$('users-prev').disabled=usersOffset===0;$('users-next').disabled=!result.more;}
async function portraits(){for(const url of blobs)URL.revokeObjectURL(url);blobs=[];const result=await data(`/api/portraits?offset=${photosOffset}`),list=$('portrait-list');list.replaceChildren();if(!result.portraits.length)empty(list,'No uploaded card portraits to review yet.');for(const portrait of result.portraits){const tile=el('article',null,'portrait'),button=el('button',null,'image-button'),img=el('img');img.alt=`Portrait for ${portrait.name||'Acquenta user'}`;button.setAttribute('aria-label',img.alt);button.append(img);button.onclick=()=>{$('large-image').src=img.src;$('image-dialog').showModal();};const details=el('div',null,'details');details.append(el('h3',portrait.name||'Acquenta user'),el('div',portrait.hidden?'Hidden':'Visible',`pill ${portrait.hidden?'flag':''}`),el('p',time(portrait.created_at),'muted'),el('div',portrait.user_id,'uid'));if(portrait.reason)details.append(el('p',portrait.reason,'muted'));details.append(actionButton(portrait.hidden?'restore-photo':'hide-photo',portrait.id,portrait.hidden?'Restore portrait':'Hide portrait'));tile.append(button,details);list.append(tile);try{const response=await api(`/api/portraits/${portrait.id}`);const url=URL.createObjectURL(await response.blob());blobs.push(url);img.src=url;}catch{img.alt='Portrait unavailable';button.disabled=true;}}$('photos-prev').disabled=photosOffset===0;$('photos-next').disabled=!result.more;}
async function show(view=currentView){currentView=view;for(const section of ['overview','users','portraits','audit','admins','ai'])$(section).hidden=section!==view;for(const button of document.querySelectorAll('nav button'))button.classList.toggle('active',button.dataset.view===view);$('heading').textContent={overview:'Overview',users:'Users',portraits:'Portrait review',audit:'Moderation history',admins:'Administrators',ai:'AI & usage'}[view];status('Loading…');try{if(view==='ai')await renderAIUsage();if(view==='admins')await administrators();if(view==='overview')await overview();if(view==='users')await users();if(view==='portraits')await portraits();if(view==='audit')renderAudit($('audit-list'),await data('/api/audit'));status('');}catch(error){status(error.message);}}
for(const button of document.querySelectorAll('[data-view]'))button.onclick=()=>{if(auth.currentUser&&!$('dashboard').hidden)void show(button.dataset.view);};
$('google').onclick=async()=>{try{status('Opening Google sign-in…');const provider=new GoogleAuthProvider();provider.setCustomParameters({prompt:'select_account'});await signInWithPopup(auth,provider);}catch(error){status(error.code==='auth/unauthorized-domain'?'Google sign-in is awaiting domain configuration. You can use your Acquenta email and password.':error.message);}};
$('login-form').onsubmit=async event=>{event.preventDefault();try{status('Signing in…');await signInWithEmailAndPassword(auth,$('email').value,$('password').value);$('password').value='';}catch{status('Sign-in failed. Check your Acquenta email and password.');}};
$('reset').onclick=async()=>{try{await sendPasswordResetEmail(auth,$('email').value);status('If an email/password account exists, a reset email will arrive shortly.');}catch{status('Password reset could not be requested. Please retry.');}};
function lockWorkspace(){
 document.body.classList.add('signed-out');$('sidebar').hidden=true;$('workspace-header').hidden=true;$('dashboard').hidden=true;$('login').hidden=false;$('admins-nav').hidden=true;
 for(const dialog of document.querySelectorAll('dialog'))dialog.close();
 for(const id of ['stats','recent','user-list','portrait-list','audit-list','pending-deletions','admin-list','ai-stats','ai-model-usage'])$(id).replaceChildren();
 $('large-image').removeAttribute('src');for(const url of blobs)URL.revokeObjectURL(url);blobs=[];pending=null;ownerUid='';isOwner=false;currentView='overview';usersOffset=0;photosOffset=0;$('password').value='';$('delete-password').value='';
}
$('signout').onclick=async()=>{++authVersion;lockWorkspace();try{await signOut(auth);}catch(error){status(error.message);}};
onAuthStateChanged(auth,async user=>{const version=++authVersion;lockWorkspace();$('signout').hidden=!user;$('identity').textContent=user?.email||'Protected workspace';if(!user){status('');return;}try{const owner=await data('/api/me');if(version!==authVersion||auth.currentUser!==user)return;ownerUid=owner.uid;isOwner=owner.role==='owner';$('admins-nav').hidden=!isOwner;document.body.classList.remove('signed-out');$('sidebar').hidden=false;$('workspace-header').hidden=false;$('login').hidden=true;$('dashboard').hidden=false;await show();}catch(error){if(version!==authVersion)return;await signOut(auth);status(error.message);}});
async function administrators(){const result=await data('/api/admins');const list=$('admin-list');list.replaceChildren();for(const email of result.owners){const item=el('article',null,'user');item.append(el('strong',email),el('span','Owner · Protected','pill'));list.append(item);}for(const admin of result.admins){const item=el('article',null,'user'),details=el('div');details.append(el('strong',admin.email),el('p',`Added by ${admin.granted_by} · ${time(admin.created_at)}`));const remove=el('button','Remove access','danger');remove.onclick=async()=>{if(!confirm(`Remove admin access for ${admin.email}?`))return;remove.disabled=true;try{await data('/api/admins',{action:'revoke',email:admin.email});await administrators();status('Administrator access removed.');}catch(error){status(error.message);}finally{remove.disabled=false;}};item.append(details,remove);list.append(item);}}
$('admin-form').onsubmit=async event=>{event.preventDefault();const button=event.submitter;button.disabled=true;try{await data('/api/admins',{action:'grant',email:$('admin-email').value});$('admin-email').value='';await administrators();status('Administrator added. They can now sign in with their verified account.');}catch(error){status(error.message);}finally{button.disabled=false;}};
$('search-form').onsubmit=event=>{event.preventDefault();usersOffset=0;void show('users');};
$('users-prev').onclick=()=>{usersOffset=Math.max(0,usersOffset-50);void show('users');};$('users-next').onclick=()=>{usersOffset+=50;void show('users');};
$('photos-prev').onclick=()=>{photosOffset=Math.max(0,photosOffset-50);void show('portraits');};$('photos-next').onclick=()=>{photosOffset+=50;void show('portraits');};$('refresh').onclick=()=>show('portraits');
$('cancel').onclick=()=>$('moderate-dialog').close();$('close-image').onclick=()=>$('image-dialog').close();
$('moderate-form').onsubmit=async event=>{event.preventDefault();const button=event.submitter;button.disabled=true;try{await data('/api/moderate',{...pending,reason:$('reason').value});$('moderate-dialog').close();await show();status('Action saved in moderation history.');}catch(error){status(error.message);$('moderate-dialog').close();}finally{button.disabled=false;}};

function deleteUserButton(uid,label){
 const button=el('button','Delete user','danger');
 button.onclick=()=>{
  pending={action:'delete-user',target:uid};
  $('delete-target').textContent=`Account email: ${label}`;
  $('delete-reason').value='';$('delete-confirm').value='';$('delete-password').value='';
  $('delete-password-field').hidden=auth.currentUser?.providerData.some(provider=>provider.providerId==='google.com')??false;
  $('delete-error').textContent='';$('delete-dialog').showModal();
 };
 return button;
}
async function pendingDeletions(){
 const rows=await data('/api/deletions');const list=$('pending-deletions');list.replaceChildren();
 if(!rows.length)return;
 list.append(el('h2','Pending deletions'),el('p','These deletions have not finished. Retry to remove the remaining cloud data and Firebase login.'));
 for(const row of rows){const item=el('article',null,'user');item.append(el('div',row.email||row.user_id,'uid'));if(row.email)item.append(deleteUserButton(row.user_id,row.email));else item.append(el('span','Email unavailable. Contact support to finish cleanup.'));list.append(item);}
}
$('delete-cancel').onclick=()=>$('delete-dialog').close();
$('delete-form').onsubmit=async event=>{
 event.preventDefault();const button=event.submitter;button.disabled=true;$('delete-error').textContent='';
 try{
  const user=auth.currentUser;if(!user)throw new Error('Please sign in again.');
  const token=await user.getIdTokenResult();
  if(Date.now()/1000-Number(token.claims.auth_time)>240){
   if(user.providerData.some(provider=>provider.providerId==='google.com')){
    const provider=new GoogleAuthProvider();provider.setCustomParameters({prompt:'select_account',login_hint:user.email});await reauthenticateWithPopup(user,provider);
   }else{
    if(!$('delete-password').value)throw new Error('Enter your owner password to confirm your sign-in.');
    await reauthenticateWithCredential(user,EmailAuthProvider.credential(user.email,$('delete-password').value));
   }
  }
  $('delete-password').value='';await user.getIdToken(true);
  await data('/api/moderate',{...pending,reason:$('delete-reason').value,confirmation:$('delete-confirm').value});
  $('delete-dialog').close();await show('users');status('User login and cloud profile deleted. The action is recorded in moderation history.');
 }catch(error){$('delete-error').textContent=error.message;}finally{button.disabled=false;}
};

const aiTools=[
 ['groq','openai/gpt-oss-120b','GPT OSS 120B','Card conversation, drafting, skills, memory cues and text cleanup'],
 ['groq','whisper-large-v3','Whisper Large V3','Online speech transcription'],
 ['groq','canopylabs/orpheus-v1-english','Orpheus English','Online spoken responses'],
 ['cloudflare','@cf/baai/bge-small-en-v1.5','BGE Small English','Smart Recall and background indexing'],
 ['cloudflare','@cf/meta/llama-3.2-3b-instruct','Llama 3.2 · 3B','Optional text path when no Groq key is configured'],
];
const aiNumber=value=>Number(value||0).toLocaleString();
function quotaReset(value,observedAt){
 if(!value||!/^([0-9]+(?:\.[0-9]+)?(?:h|m|s|ms|us|µs))+$/.test(value))return null;
 let milliseconds=0;for(const match of value.matchAll(/([0-9]+(?:\.[0-9]+)?)(ms|us|µs|h|m|s)/g))milliseconds+=Number(match[1])*({h:3600000,m:60000,s:1000,ms:1,us:.001,'µs':.001}[match[2]]);
 const result=Date.parse(observedAt)+milliseconds;return Number.isFinite(result)?result:null;
}
function quotaBlock(parent,snapshot,kind,title){
 const headers=snapshot.headers,limit=Number(headers['limit-'+kind]),remaining=Number(headers['remaining-'+kind]);
 if(!headers['limit-'+kind]||!headers['remaining-'+kind]||!Number.isFinite(limit)||limit<=0||!Number.isFinite(remaining)||remaining<0||remaining>limit)return false;
 const used=limit-remaining,reset=quotaReset(headers['reset-'+kind],snapshot.observed_at),expired=reset!==null&&Date.now()>=reset;
 const block=el('div',null,'ai-provider-quota');block.append(el('h4',title+(expired?' · expired snapshot':'')));
 const meter=el('progress');meter.max=limit;meter.value=used;meter.setAttribute('aria-label',`${title}, last reported ${aiNumber(used)} used of ${aiNumber(limit)}`);
 block.append(meter,el('p',`${aiNumber(used)} / ${aiNumber(limit)} used (${(used/limit*100).toFixed(1)}%) · ${aiNumber(remaining)} remaining at snapshot`));
 if(reset!==null)block.append(el('p',`Reset ${expired?'was expected':'expected'}: ${new Date(reset).toLocaleString()}`,'muted'));
 else if(headers['reset-'+kind])block.append(el('p',`Provider reset interval: ${headers['reset-'+kind]}`,'muted'));
 parent.append(block);return true;
}
async function renderAIUsage(){
 for(const id of ['ai-stats','ai-model-usage'])$(id).replaceChildren();$('ai-updated').textContent='';$('ai-coverage').textContent='';
 const result=await data('/api/ai-usage');if($('dashboard').hidden||currentView!=='ai')return;
 const summary=result.summary;
 for(const [label,value] of [['Model calls today (UTC)',summary.today],['Model calls · last 7 days',summary.week],['Model calls this month (UTC)',summary.month],['Total calls since tracking began',summary.trackedTotal]]){
  const tile=el('article',null,'stat');tile.append(el('small',label),el('strong',aiNumber(value)));$('ai-stats').append(tile);
 }
 $('ai-updated').textContent=`Usage refreshed ${new Date(result.generatedAt).toLocaleString()} · Counts across all app users · Daily totals use UTC`;
 $('ai-coverage').textContent=summary.trackingSince?`Per-model tracking began ${new Date(summary.trackingSince).toLocaleString()}. Earlier requests cannot be reliably split by model; they are excluded from these totals.`:'Per-model tracking is enabled. Calls and quota snapshots will appear as each tool is used. Earlier requests cannot be reliably split by model.';
 const tools=[...aiTools];for(const row of result.models)if(!tools.some(tool=>tool[0]===row.provider&&tool[1]===row.model))tools.push([row.provider,row.model,row.model,'Additional metered model']);
 for(const [provider,model,name,description] of tools){
  const row=result.models.find(item=>item.provider===provider&&item.model===model),snapshot=result.quotas.find(item=>item.provider===provider&&item.model===model);
  const card=el('article',null,'panel');card.append(el('span',provider==='groq'?'GROQ':'CLOUDFLARE','badge'),el('h3',name),el('code',model),el('p',description));
  card.append(el('p',row?`${aiNumber(row.today)} calls today · ${aiNumber(row.month)} this month · ${aiNumber(row.calls)} since tracking began`:'No tracked calls for this model yet.'));
  if(row){card.append(el('p',`${aiNumber(row.succeeded)} completed · ${aiNumber(row.failed)} failed`,'muted'));
   card.append(el('p',row.token_responses>0?`Reported tokens: ${aiNumber(row.input_tokens)} input + ${aiNumber(row.output_tokens)} output · ${aiNumber(row.token_responses)} of ${aiNumber(row.calls)} calls supplied complete token usage`:'Token usage: not reported by this model.','muted'));
   if(row.characters>0)card.append(el('p',`${aiNumber(row.characters)} input characters sent (not billed units)`,'muted'));
   if(row.audio_responses>0)card.append(el('p',`${Number(row.audio_seconds).toFixed(1)} audio seconds reported across ${aiNumber(row.audio_responses)} calls (not billed units)`,'muted'));
  }
  if(provider==='cloudflare'&&row&&row.today_token_responses>0){
   const rate={'@cf/baai/bge-small-en-v1.5':[1841,0],'@cf/meta/llama-3.2-3b-instruct':[4625,30475]}[model];
   if(rate){const neurons=(Number(row.today_input_tokens)*rate[0]+Number(row.today_output_tokens)*rate[1])/1000000;
    const block=el('div',null,'ai-provider-quota');block.append(el('h4','Estimated app neuron usage today'),el('p',`${neurons.toLocaleString(undefined,{maximumFractionDigits:4})} neurons · ${(neurons/10000*100).toFixed(5)}% of the 10,000-neuron daily included account allocation`));
    block.append(el('p',`Based on provider-reported tokens from ${row.today_token_responses} of ${row.today} calls today and Cloudflare rates checked 20 October 2026. Models share the account allocation; other apps and unmeasured calls are excluded. This is not the account’s remaining balance or a hard spending cap.`,'muted'));card.append(block);
   }
  }
  if(snapshot){
   let visible=quotaBlock(card,snapshot,'requests','Organisation daily request quota');visible=quotaBlock(card,snapshot,'tokens','Organisation token quota per minute')||visible;
   if(!visible)card.append(el('p','Provider did not return a complete quota measurement.','muted'));
   card.append(el('p',`Provider snapshot: ${new Date(snapshot.observed_at).toLocaleString()}. Values are historical until another call updates them.`,'muted'));
  }else card.append(el('p',provider==='groq'?'Provider quota: awaiting this model’s next response.':'Account neuron quota: unavailable through the current Workers AI binding. View account usage in Cloudflare.','muted'));
  $('ai-model-usage').append(card);
 }
}
$('ai-refresh').onclick=()=>show('ai');
