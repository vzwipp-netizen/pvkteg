import {createClient} from '@supabase/supabase-js';
const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
export const configured = Boolean(url && key && !url.includes('YOUR_PROJECT') && !key.includes('YOUR_'));
export const supabase = configured ? createClient(url!, key!) : null;
export type Profile = {id:string; username:string; display_name:string; avatar_url:string|null; stars:number; is_admin?:boolean};
export async function getProfile(userId:string) {
  if (!supabase) return null;
  const {data,error}=await supabase.from('profiles').select('*').eq('id',userId).maybeSingle();
  if(error) throw error; return data as Profile|null;
}