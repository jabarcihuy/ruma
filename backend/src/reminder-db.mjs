const encode = v => v===null?{nullValue:null}:v instanceof Date?{timestampValue:(v.firestoreTimestamp??v.toISOString())}:
  typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?{integerValue:String(v)}:
  typeof v==='string'?{stringValue:v}:Array.isArray(v)?{arrayValue:{values:v.map(encode)}}:
  {mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,encode(x)]))}};
const decode = v => 'nullValue' in v?null:'timestampValue' in v?Object.assign(new Date(v.timestampValue),{firestoreTimestamp:v.timestampValue}):
  'booleanValue' in v?v.booleanValue:'integerValue' in v?Number(v.integerValue):
  'stringValue' in v?v.stringValue:'arrayValue' in v?(v.arrayValue.values??[]).map(decode):
  Object.fromEntries(Object.entries(v.mapValue?.fields??{}).map(([k,x])=>[k,decode(x)]));
export function reminderDatabase(project,token,fetcher=fetch) {
  if(!/^[a-z0-9-]+$/.test(project)) throw Error('invalid_project');
  const name=`projects/${project}/databases/(default)/documents`,base=`https://firestore.googleapis.com/v1/${name}`;
  async function api(path,method,body) {
    const r=await fetcher(base+path,{method,redirect:'manual',signal:AbortSignal.timeout(10000),
      headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
    if(r.status===404) return null;
    if(!r.ok) {const e=Error([409,412].includes(r.status)?'conflict':'database_unavailable');throw e;}
    return r.json();
  }
  const document = d => ({path:d.name.slice(name.length+1),version:d.updateTime,data:decode({mapValue:{fields:d.fields}})});
  return {
    async get(path) {const d=await api('/'+path,'GET');return d?document(d):null;},
    async query(parent,query) {return (await api((parent?'/'+parent:'')+':runQuery','POST',{structuredQuery:query})).filter(x=>x.document).map(x=>document(x.document));},
    async commit(writes) {return api(':commit','POST',{writes:writes.map(w=>({update:{name:name+'/'+w.path,fields:encode(w.data).mapValue.fields},currentDocument:w.version?{updateTime:w.version}:{exists:false}}))});},
  };
}
