import {nextWeekly,reminderOccurrence} from './recurrence.mjs';
import {googleAccess} from './quota.mjs';
import {reminderDatabase} from './reminder-db.mjs';
const eligible = (j,a,now) => {
 const meeting=reminderOccurrence(a,j);
 return j.enabled && a && a.deletedAt===null && a.status==='planned' && meeting?.status==='planned' &&
  a.version===j.sourceVersion && (meeting.startAtUtc??meeting.deadlineAtUtc)?.getTime()===j.anchorAtUtc?.getTime() && j.anchorAtUtc>now;
};
export const notificationId = (agenda,generation) => `${agenda}_${generation}`;
export function fcmPayload(uid,j,token,now) {
  return {message:{token,notification:{title:'Pengingat Ruma',body:'Ada agenda yang perlu kamu cek'},
    data:{uid,agendaId:j.agendaId,sourceVersion:String(j.sourceVersion),generation:String(j.generation),notificationId:notificationId(j.agendaId,j.generation),...(j.occurrenceDate?{occurrenceDate:j.occurrenceDate}:{})},
    android:{priority:'high',ttl:`${Math.max(0,Math.min(86400,Math.floor((j.anchorAtUtc-now)/1000)))}s`,
      collapse_key:notificationId(j.agendaId,j.generation),notification:{channel_id:'ruma_agenda_v1',icon:'ic_stat_ruma',tag:notificationId(j.agendaId,j.generation)}}}};
}
export async function reservePush(db,uid,now) {
  const day=now.toISOString().slice(0,10),minute=now.toISOString().slice(0,16).replaceAll(':','-');
  const buckets=[[`push_global_day_${day}`,100],[`push_global_minute_${minute}`,10],[`push_user_${uid}_minute_${minute}`,5]];
  const docs=await Promise.all(buckets.map(([key])=>db.get('usage/'+key)));
  if(docs.some((d,i)=>(d?.data.count??0)>=buckets[i][1])) return false;
  await db.commit(buckets.map(([key],i)=>({path:'usage/'+key,version:docs[i]?.version,data:{count:(docs[i]?.data.count??0)+1}})));
  return true;
}

// Bounded one-off agenda slice: 5 jobs/tick, 3 devices/job; recurrence remains a separate feature.
export async function dispatchReminders(env,services={}) {
  if(env.NOTIFICATIONS_ENABLED!=='true') return {disabled:true,processed:0};
  const clock=()=>services.now??new Date();
  const now=clock(),fetcher=services.fetch??fetch;
  const token=services.token??await googleAccess({...env,GOOGLE_OAUTH_SCOPE:'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging'},fetcher);
  const db=services.db??reminderDatabase(env.FIREBASE_PROJECT_ID,token,fetcher);
  const jobs=await db.query('',{from:[{collectionId:'reminders',allDescendants:true}],where:{compositeFilter:{op:'AND',filters:[
    {fieldFilter:{field:{fieldPath:'status'},op:'IN',value:{arrayValue:{values:[{stringValue:'queued'},{stringValue:'leased'}]}}}},
    {fieldFilter:{field:{fieldPath:'availableAtUtc'},op:'LESS_THAN_OR_EQUAL',value:{timestampValue:now.toISOString()}}}]}},
    orderBy:[{field:{fieldPath:'availableAtUtc'},direction:'ASCENDING'}],limit:5});
  const stats={processed:0,sent:0,expired:0,retry:0,stale:0};
  for(const found of jobs) {
    let claimed;
    try {
      const parts=found.path.split('/');
      if(parts.length!==4 || parts[0]!=='users' || parts[2]!=='reminders' || parts[3]!==found.data.agendaId) continue;
      const uid=parts[1],j=found.data,id=notificationId(j.agendaId,j.generation);
      if(!['queued','leased'].includes(j.status) || !(j.availableAtUtc<=now)) continue;
      const lease=crypto.randomUUID(),claimTime=clock();
      claimed={...j,status:'leased',attempts:j.attempts+1,leaseId:lease,leaseUntilUtc:new Date(+claimTime+60000),availableAtUtc:new Date(+claimTime+60000)};
      await db.commit([{...found,data:claimed}]);stats.processed++;
      async function finish(status,extra={}) {
        const current=await db.get(found.path);
        if(current?.data.generation!==j.generation || current.data.leaseId!==lease || current.data.sourceVersion!==j.sourceVersion) {stats.stale++;return;}
        let data={...current.data,status,...extra,updatedAt:clock()};
        if(['sent','expired','failed'].includes(status)) {
          const raw=await db.get(`users/${uid}/agenda/${j.agendaId}`);
          if(raw?.data.recurrence?.type==='weekly' && raw.data.version===j.sourceVersion) {
            let next;try {next=nextWeekly(raw.data,new Date(Math.max(+clock(),+j.anchorAtUtc)));}catch {next=null;}
            if(next){const due=new Date(+next.startAtUtc-j.leadMinutes*60000);data={...data,generation:j.generation+1,occurrenceDate:next.occurrenceDate,anchorAtUtc:next.startAtUtc,dueAtUtc:due,availableAtUtc:due,status:'queued',attempts:0,leaseId:null,leaseUntilUtc:null,lastError:null,deviceResults:{}};}
          }
        }
        const writes=[{...current,data}];
        if(status==='sent') {
          const inboxPath=`users/${uid}/notifications/${id}`,existing=await db.get(inboxPath);
          if(!existing) writes.push({path:inboxPath,data:{agendaId:j.agendaId,generation:j.generation,sourceVersion:current.data.sourceVersion,createdAt:clock(),readAt:null,...(j.occurrenceDate?{occurrenceDate:j.occurrenceDate}:{})}});
        }
        await db.commit(writes);
      }
      const agenda=await db.get(`users/${uid}/agenda/${j.agendaId}`);
      if(!eligible(j,agenda?.data,clock())) {
        const status=j.anchorAtUtc && j.anchorAtUtc<=clock()?'expired':'cancelled';await finish(status);stats.expired++;continue;
      }
      if(claimed.attempts>5) {await finish('failed',{lastError:'attempt_limit'});continue;}
      const devices=await db.query(`users/${uid}`,{from:[{collectionId:'devices'}],where:{fieldFilter:{field:{fieldPath:'enabled'},op:'EQUAL',value:{booleanValue:true}}},limit:3});
      if(!devices.length) {await finish('failed',{lastError:'no_active_device'});continue;}
      if(!await reservePush(db,uid,clock())) {await finish('queued',{availableAtUtc:new Date(+clock()+60000),lastError:'rate_limited'});stats.retry++;continue;}
      const latest=await db.get(found.path),source=await db.get(`users/${uid}/agenda/${j.agendaId}`);
      if(latest?.data.leaseId!==lease || latest.data.generation!==j.generation || !eligible(latest.data,source?.data,clock())) {
        await finish('queued',{availableAtUtc:new Date(+clock()+60000),lastError:'source_changed'});continue;
      }
      const results={...j.deviceResults};let temporary=false,retryAfter=0;
      for(const device of devices) {
        if(['sent','invalid','failed'].includes(results[device.path])) continue;
        try {
          const active=await db.get(device.path);
          if(!active?.data.enabled || active.data.token!==device.data.token) continue;
          const guard=await db.get(found.path),currentSource=await db.get(`users/${uid}/agenda/${j.agendaId}`);
          if(guard?.data.leaseId!==lease || guard.data.generation!==j.generation || !eligible(guard.data,currentSource?.data,clock())) break;
          // Renew before each network send; a slow previous device must not leave an expired lease.
          const until=new Date(+clock()+60000);
          await db.commit([{...guard,data:{...guard.data,leaseUntilUtc:until,availableAtUtc:until}}]);
          const response=await fetcher(`https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,{
            method:'POST',redirect:'manual',signal:AbortSignal.timeout(10000),headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
            body:JSON.stringify(fcmPayload(uid,guard.data,device.data.token,clock()))});
          if(response.ok) results[device.path]='sent';
          else {
            const error=await response.json().catch(()=>({}));
            if(error.error?.details?.some(x=>x.errorCode==='UNREGISTERED')) {
              results[device.path]='invalid';await db.commit([{...active,data:{...active.data,enabled:false,updatedAt:clock()}}]);
            } else if(response.status===429 || response.status>=500) {
              temporary=true;
              const value=response.headers.get('Retry-After');
              retryAfter=Math.max(retryAfter,/^\d+$/.test(value??'')?Number(value)*1000:Math.max(0,Date.parse(value)-now)||0);
            } else results[device.path]='failed';
          }
        } catch { temporary=true; }
        // Persist successes before contacting the next device; do not resend successes on retry.
        const current=await db.get(found.path);
        if(current?.data.generation!==j.generation || current.data.leaseId!==lease) {stats.stale++;break;}
        await db.commit([{...current,data:{...current.data,deviceResults:results,updatedAt:clock()}}]);
      }
      const wait=Math.max(retryAfter,[60000,120000,300000][Math.min(2,claimed.attempts-1)]);
      const retryNow=clock();
      if(temporary && claimed.attempts<5 && +retryNow+wait<+j.anchorAtUtc) {
        await finish('queued',{availableAtUtc:new Date(+retryNow+wait),deviceResults:results,lastError:'temporary_fcm'});stats.retry++;
      } else {
        const status=Object.values(results).includes('sent')?'sent':'failed';
        await finish(status,{deviceResults:results,lastError:status==='sent'?null:'delivery_failed'});if(status==='sent')stats.sent++;
      }
    } catch(error) { if(error.message==='conflict') stats.stale++; else stats.retry++; }
  }
  return stats;
}
