const dayMs=86400000,weekMs=7*dayMs;
const key=d=>d.toISOString().slice(0,10);
function day(s){if(typeof s!=='string'||!/^(20\d{2}|2100)-\d{2}-\d{2}$/.test(s))throw Error('invalid_series_date');const d=new Date(s+'T00:00:00Z');if(!Number.isFinite(+d)||key(d)!==s)throw Error('invalid_series_date');return d;}
function input(v){
 if(!v||typeof v.title!=='string'||v.title.length<1||v.title.length>120||v.kind!=='class'||!Number.isInteger(v.durationMinutes)||v.durationMinutes<5||v.durationMinutes>720||!['planned','completed','cancelled'].includes(v.status)||v.deadlineAtUtc!=null||v.recurrence)throw Error('invalid_series_input');
 const start=new Date(v.startAtUtc);if(!Number.isFinite(+start)||start.getUTCFullYear()<2000||start.getUTCFullYear()>2100)throw Error('invalid_series_time');
 return {...v,startAtUtc:start,endAtUtc:new Date(+start+v.durationMinutes*60000)};
}
function maps(a){const r=a.recurrence;if(!r||r.type!=='weekly'||a.kind!=='class')throw Error('invalid_series');const origin=day(r.originDate);if(r.untilLocalDate!=null&&+day(r.untilLocalDate)<+origin)throw Error('invalid_series_end');
 const result={origin};
 for(const f of ['exceptions','changes']){if(typeof r[f]!=='string'||r[f].length>60000)throw Error('series_size');const m=JSON.parse(r[f]);if(!m||Array.isArray(m)||Object.keys(m).length>(f==='exceptions'?64:16))throw Error('series_count');for(const [d,v] of Object.entries(m)){if(+day(d)<+origin||(+day(d)-origin)%weekMs!==0)throw Error('invalid_original_date');input(v);}result[f]=m;}
 return result;
}
function meeting(a,date,plan){const {origin,changes,exceptions}=plan,d=day(date),n=(d-origin)/weekMs;if(n<0||!Number.isInteger(n)||a.recurrence.untilLocalDate!=null&&date>a.recurrence.untilLocalDate)return null;
 let v={...a,recurrence:undefined},base=origin;
 for(const f of Object.keys(changes).sort())if(f<=date){v=changes[f];base=day(f);}
 const p=input(v),start=new Date(+p.startAtUtc+(d-base));let result={...p,startAtUtc:start,endAtUtc:new Date(+start+p.durationMinutes*60000),status:a.status==='planned'?p.status:a.status,occurrenceDate:date};
 if(exceptions[date])result={...input(exceptions[date]),occurrenceDate:date};if(a.status!=='planned')result.status=a.status;return result;
}
export function weeklyMeeting(a,date){return meeting(a,date,maps(a));}
export function nextWeekly(a,after){if(a.deletedAt!=null||a.status!=='planned')return null;const plan=maps(a),{origin,changes,exceptions}=plan,candidates=[];
 for(const [date,v] of Object.entries({[key(origin)]:{...a,recurrence:undefined},...changes})){const p=input(v);let n=Math.max(0,Math.floor((after-p.startAtUtc)/weekMs));for(let i=0;i<82;i++,n++){const m=meeting(a,key(new Date(+day(date)+n*weekMs)),plan);if(m?.status==='planned'&&m.startAtUtc>after){candidates.push(m);if(!Object.hasOwn(exceptions,m.occurrenceDate))break;}}}
 for(const date of Object.keys(exceptions)){const m=meeting(a,date,plan);if(m?.status==='planned'&&m.startAtUtc>after)candidates.push(m);}
 candidates.sort((a,b)=>a.startAtUtc-b.startAtUtc);return candidates[0]??null;
}
export function reminderOccurrence(a,j){try{return a?.recurrence?.type==='weekly'?weeklyMeeting(a,j.occurrenceDate):a;}catch{return null;}}
