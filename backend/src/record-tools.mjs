const nullableText = {type:['string','null'], maxLength:120};
export const patchFields = {
  title: nullableText,
  durationMinutes: {type:['integer','null'],minimum:5,maximum:720},
  startLocal: nullableText, deadlineLocal: nullableText,
  status: {enum:['planned','completed','cancelled',null]},
  amountRupiah: {type:['integer','null'],minimum:1,maximum:1000000000},
  categoryId: {enum:['food','transport','housing','other','allowance','work','other_income',null]},
  localDate: nullableText,
};
export const READ_TOOL = {type:'function',function:{name:'read_records',
  description:'Baca data pengguna lewat aplikasi. Angka dan jawaban dihitung aplikasi, bukan perkiraan model. Satu periode per pesan.',
  parameters:{type:'object',properties:{kind:{enum:['agenda','summary','history']},
    date:{type:'string',description:'YYYY-MM-DD untuk agenda, YYYY-MM untuk uang.'},
    categoryId:{enum:['food','transport','housing','other','allowance','work','other_income',null]}},
    required:['kind','date','categoryId'],additionalProperties:false}}};
export const CHANGE_TOOL = {type:'function',function:{name:'prepare_change',
  description:'Usulkan edit/hapus SATU catatan lama. Nama harus persis dari pengguna, bukan menebak ID. Pengguna harus meninjau sebelum disimpan. Jika beberapa perubahan diminta, minta pengguna mengirim satu per satu.',
  parameters:{type:'object',properties:{recordType:{enum:['agenda','transaction']},
    action:{enum:['update','delete']}, targetTitle:{type:'string',minLength:1,maxLength:1000},
    targetDate:{type:['string','null'],description:'Tanggal catatan yang dicari, bukan tanggal baru. YYYY-MM-DD. Transaksi wajib bertanggal untuk menentukan bulan.'},
    sourceQuote:{type:'string'}, patch:{type:'object',properties:patchFields,required:Object.keys(patchFields),additionalProperties:false}},
    required:['recordType','action','targetTitle','targetDate','sourceQuote','patch'],additionalProperties:false}}};
export const CLARIFY_TOOL = {type:'function',function:{name:'ask_clarification',
  description:'Tanyakan rincian yang belum ada tanpa membuat draf parsial.',
  parameters:{type:'object',properties:{reason:{enum:['target_details','one_change','one_period']}},required:['reason'],additionalProperties:false}}};
const sameKeys = (v,keys) => v && !Array.isArray(v) && typeof v==='object' && Object.keys(v).sort().join() === [...keys].sort().join();
export function dateValid(v) {
  return typeof v==='string' && /^(20\d{2}|2100)-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(v)) && new Date(v).toISOString().slice(0,10)===v;
}
export function timeValid(v) { return typeof v==='string' && /^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):[0-5]\d$/.test(v) && dateValid(v.slice(0,10)); }
export function normalizeRecordTool(message, text, today) {
  const calls=message?.tool_calls;
  if (!calls?.length || !['read_records','prepare_change','ask_clarification'].includes(calls[0]?.function?.name)) return null;
  if(calls.length!==1 || calls[0].type!=='function' || !calls[0].id) throw new Error('invalid_model_output');
  let a; try {a=JSON.parse(calls[0].function.arguments);} catch {throw new Error('invalid_model_output');}
  const invalid=()=>{throw new Error('invalid_model_output');};
  if(calls[0].function.name==='ask_clarification') {
    if(!sameKeys(a,['reason']) || !['target_details','one_change','one_period'].includes(a.reason)) invalid();
    return {type:'clarification', reason:a.reason, content:'Perlu rincian tambahan.',items:[]};
  }
  if(calls[0].function.name==='read_records') {
    if(!sameKeys(a,['kind','date','categoryId']) || !['agenda','summary','history'].includes(a.kind)
      || !(a.kind==='agenda'?dateValid(a.date):typeof a.date==='string' && /^(20\d{2}|2100)-(0[1-9]|1[0-2])$/.test(a.date))
      || ![null,'food','transport','housing','other','allowance','work','other_income'].includes(a.categoryId)
      || a.kind!=='history' && a.categoryId!==null) invalid();
    return {type:'read_request',content:'Membaca catatan...',query:a};
  }
  if(!sameKeys(a,['recordType','action','targetTitle','targetDate','sourceQuote','patch'])
    || !['agenda','transaction'].includes(a.recordType) || !['update','delete'].includes(a.action)
    || typeof a.targetTitle!=='string' || !a.targetTitle.trim() || a.targetTitle.length>1000
    || typeof a.sourceQuote!=='string' || !a.sourceQuote.trim() || !text.includes(a.sourceQuote)
    || !a.sourceQuote.toLowerCase().includes(a.targetTitle.toLowerCase())
    || !(a.targetDate===null ? a.recordType==='agenda' : dateValid(a.targetDate))
    || !sameKeys(a.patch,Object.keys(patchFields))) invalid();
  const p=a.patch;
  for(const [k,v] of Object.entries(p)) {
    if(v===null) continue;
    if(k==='title' && (typeof v!=='string' || !v.trim() || v.length>120)) invalid();
    if(k==='durationMinutes' && (!Number.isInteger(v)||v<5||v>720)) invalid();
    if(k==='amountRupiah' && (!Number.isInteger(v)||v<1||v>1000000000)) invalid();
    if(['startLocal','deadlineLocal'].includes(k) && !timeValid(v)) invalid();
    if(k==='localDate' && (!dateValid(v)||v>today)) invalid();
    if(k==='status' && !['planned','completed','cancelled'].includes(v)) invalid();
    if(k==='categoryId' && !['food','transport','housing','other','allowance','work','other_income'].includes(v)) invalid();
  }
  if(a.action==='delete' ? Object.values(p).some(v=>v!==null) : Object.values(p).every(v=>v===null)) invalid();
  if((a.recordType==='agenda'?['amountRupiah','categoryId','localDate']:['durationMinutes','startLocal','deadlineLocal','status']).some(k=>p[k]!==null)) invalid();
  return {type:'change_proposal',content:'Periksa perubahan. Data belum disimpan.',change:a};
}
