import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type"};
serve(async (req) => {
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 try {
  const auth=req.headers.get("Authorization");
  if(!auth) return new Response(JSON.stringify({error:"Unauthorized"}),{status:401,headers:{...cors,"Content-Type":"application/json"}});
  const supabase=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:auth}}});
  const {data:{user},error:userError}=await supabase.auth.getUser();
  if(userError||!user) return new Response(JSON.stringify({error:"Unauthorized"}),{status:401,headers:{...cors,"Content-Type":"application/json"}});
  const body=await req.json(); const messages=Array.isArray(body.messages)?body.messages.slice(-20):[];
  if(!messages.length||messages.some((m:any)=>!["user","assistant"].includes(m.role)||typeof m.content!=="string"||m.content.length>12000)) throw new Error("Invalid messages");
  const key=Deno.env.get("OPENAI_API_KEY"); if(!key) throw new Error("OPENAI_API_KEY is not configured");
  const response=await fetch("https://api.openai.com/v1/chat/completions",{method:"POST",headers:{"Authorization":`Bearer ${key}`,"Content-Type":"application/json"},body:JSON.stringify({model:"gpt-4o-mini",messages:[{role:"system",content:"Ты PVKTEG AI — полезный русскоязычный помощник внутри мессенджера. Отвечай ясно и безопасно."},...messages],temperature:0.7})});
  const result=await response.json(); if(!response.ok) throw new Error(result.error?.message||"AI provider error");
  return new Response(JSON.stringify({answer:result.choices?.[0]?.message?.content||"Нет ответа"}),{headers:{...cors,"Content-Type":"application/json"}});
 } catch(e) { return new Response(JSON.stringify({error:String(e)}),{status:400,headers:{...cors,"Content-Type":"application/json"}}); }
});