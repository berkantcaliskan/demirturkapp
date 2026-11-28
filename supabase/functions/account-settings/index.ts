import { createClient } from 'npm:@supabase/supabase-js@2.119.2';

const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json'};
const reply = (data: unknown, status=200) => new Response(JSON.stringify(data),{status,headers});
function phone(value: string) {
  let d=value.replace(/\D/g,'');
  if(d.length===14 && d.startsWith('0090')) d=d.slice(4);
  else if(d.length===12 && d.startsWith('90')) d=d.slice(2);
  else if(d.length===11 && d.startsWith('0')) d=d.slice(1);
  return /^5\d{9}$/.test(d)?`+90${d}`:null;
}
Deno.serve(async req=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers});
  if(req.method!=='POST') return reply({error:'Yöntem desteklenmiyor.'},405);
  try{
    if(Number(req.headers.get('content-length')??0)>4096) return reply({error:'İstek çok büyük.'},413);
    const reader=req.body?.getReader();
    if(!reader) return reply({error:'Geçersiz istek.'},400);
    const chunks:Uint8Array[]=[];
    let length=0;
    while(true){
      const {done,value}=await reader.read();
      if(done) break;
      length+=value.byteLength;
      if(length>4096){await reader.cancel();return reply({error:'İstek çok büyük.'},413);}
      chunks.push(value);
    }
    const bytes=new Uint8Array(length);
    let offset=0;
    for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
    const body=JSON.parse(new TextDecoder().decode(bytes));
    if(!body || typeof body!=='object' || Array.isArray(body)) return reply({error:'Geçersiz istek.'},400);
    const url=Deno.env.get('SUPABASE_URL')!;
    const secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS')??'{}').default;
    const admin=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
    const jwt=req.headers.get('authorization')?.replace(/^Bearer\s+/i,'');
    if(!jwt) return reply({error:'Oturum açın.'},401);
    const {data:{user},error}=await admin.auth.getUser(jwt);
    if(error || !user) return reply({error:'Oturumunuz sona erdi.'},401);
    const {data:profile,error:pe}=await admin.from('profiles').select('id,full_name,contact_phone,role,staff_role,deleted_at').eq('id',user.id).single();
    if(pe || !profile || profile.deleted_at) return reply({error:'Hesap bulunamadı.'},403);
    if(body.action==='read') return reply({name:profile.full_name,email:user.email??'',phone:user.phone?`+${user.phone.replace(/^\+/,'')}`:profile.contact_phone??''});
    const checker=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
    const password=String(body.currentPassword??'');
    if(!password || password.length>128) return reply({error:'Mevcut parolanızı girin.'},400);
    const credentials=user.email?{email:user.email,password}:{phone:user.phone!,password};
    const {data:reauth,error:re}=await checker.auth.signInWithPassword(credentials);
    if(re || reauth.user?.id!==user.id) return reply({error:'Mevcut parola hatalı.'},403);
    // Reauthentication creates a short-lived check session; never leave it behind.
    if(reauth.session) await admin.auth.admin.signOut(reauth.session.access_token,'local');
    if(body.action==='delete'){
      if(profile.role!=='customer' || profile.staff_role) return reply({error:'Personel hesapları yönetim tarafından kapatılır.'},403);
      const {error:e}=await admin.rpc('portal_delete_account',{p_user_id:user.id});
      if(e) {console.error('Account deletion failed',e.code);return reply({error:'Hesap silinemedi. Tekrar deneyin.'},400);}
      return reply({ok:true});
    }
    if(body.action==='password'){
      const next=String(body.password??'');
      if(profile.staff_role?!/^(?=.*[a-zA-ZçÇğĞıİöÖşŞüÜ])(?=.*\d).{6,128}$/.test(next):!/^\d{6}$/.test(next)) return reply({error:'Yeni parolayı kontrol edin.'},400);
      const {error:e}=await admin.auth.admin.updateUserById(user.id,{password:next});
      if(e) return reply({error:'Parola değiştirilemedi.'},400);
      return reply({ok:true});
    }
    if(body.action!=='update') return reply({error:'Geçersiz işlem.'},400);
    const name=String(body.name??'').trim(), nextPhone=phone(String(body.phone??''));
    if(name.length<3 || name.length>100 || !nextPhone) return reply({error:'Ad soyad ve telefon numarasını kontrol edin.'},400);
    const nextEmail=String(body.email??'').trim().toLowerCase();
    if(nextEmail.length>254) return reply({error:'Geçerli bir e-posta girin.'},400);
    if(user.email && nextEmail && nextEmail!==user.email.toLowerCase()) return reply({error:'E-posta adresi değiştirilemez.'},400);
    if(!user.email && nextEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(nextEmail)) return reply({error:'Geçerli bir e-posta girin.'},400);
    const {data:reserved,error:rosterError}=await admin.from('staff_account_roster').select('phone').eq('phone',nextPhone);
    if(rosterError) return reply({error:'Telefon kontrol edilemedi.'},503);
    if(reserved?.length && nextPhone!==`+${user.phone?.replace(/^\+/,'')}`) return reply({error:'Bu telefon numarası kullanılamıyor.'},400);
    const {error:e}=await admin.auth.admin.updateUserById(user.id,{phone:nextPhone,phone_confirm:true,...(!user.email && nextEmail?{email:nextEmail,email_confirm:true}:{}),user_metadata:{...user.user_metadata,full_name:name,username_phone:nextPhone}});
    if(e) return reply({error:'Numara veya e-posta kullanılamıyor. Bilgilerinizi kontrol edin.'},400);
    const {error:saveError}=await admin.rpc('portal_save_account',{p_user_id:user.id,p_name:name,p_phone:nextPhone});
    if(saveError) return reply({error:'Hesap bilgileri eşitlenemedi. Kaydetmeyi tekrar deneyin.'},400);
    const {error:emailError}=await admin.from('customers').update({email:user.email||nextEmail}).eq('auth_user_id',user.id);
    if(emailError) return reply({error:'Hesap bilgileri eşitlenemedi. Kaydetmeyi tekrar deneyin.'},400);
    return reply({ok:true});
  }catch{ return reply({error:'İşlem tamamlanamadı. Tekrar deneyin.'},400); }
});
