-- PVKTEG database schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null,
 display_name text not null default 'User',
 avatar_url text,
 stars integer not null default 100 check (stars >= 0),
 created_at timestamptz not null default now()
);
create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references public.profiles(id) on delete cascade,
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 content text not null,
 kind text not null default 'text' check (kind in ('text','voice','image')),
 created_at timestamptz not null default now()
);
create index if not exists messages_pair_created on public.messages(sender_id,recipient_id,created_at);
create table if not exists public.gift_inventory (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 gift_id text not null,
 gift_name text not null,
 sender_id uuid references public.profiles(id),
 created_at timestamptz not null default now()
);
create table if not exists public.gift_catalog (
 gift_id text primary key,
 gift_name text not null,
 cost integer not null check(cost > 0),
 is_collectible boolean not null default false
);
insert into public.gift_catalog(gift_id,gift_name,cost,is_collectible) values
 ('rose','Космическая роза',20,false),('cat','Киберкот',75,false),('planet','Планета PVK',250,true),('crown','Корона галактики',700,true),('dragon','Неоновый дракон',1200,true)
on conflict(gift_id) do nothing;
alter table public.profiles enable row level security;
alter table public.messages enable row level security;
alter table public.gift_inventory enable row level security;
alter table public.gift_catalog enable row level security;
create policy "profiles readable by authenticated" on public.profiles for select to authenticated using (true);
create policy "profile owner updates" on public.profiles for update to authenticated using (auth.uid()=id) with check(auth.uid()=id);
create policy "messages visible to participants" on public.messages for select to authenticated using(auth.uid()=sender_id or auth.uid()=recipient_id);
create policy "sender creates message" on public.messages for insert to authenticated with check(auth.uid()=sender_id);
create policy "gift owner sees inventory" on public.gift_inventory for select to authenticated using(auth.uid()=owner_id or auth.uid()=sender_id);
create policy "catalog readable" on public.gift_catalog for select to authenticated using(true);
-- Provision profile after signup; username is generated from email prefix + random suffix.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare uname text;
begin
 uname := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)),'[^a-zA-Z0-9_]','','g')) || '_' || substr(new.id::text,1,6);
 insert into public.profiles(id,username,display_name,stars) values(new.id,uname,coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)),100);
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
-- Secure, atomic gift purchase/transfer. Stars are demo credits; real-money top-ups are not enabled.
create or replace function public.send_gift(p_recipient_id uuid,p_gift_id text,p_gift_name text,p_cost integer)
returns uuid language plpgsql security definer set search_path=public as $$
declare sender uuid := auth.uid(); gift_cost integer; inventory_id uuid;
begin
 if sender is null then raise exception 'Authentication required'; end if;
 select cost into gift_cost from public.gift_catalog where gift_id=p_gift_id and gift_name=p_gift_name;
 if gift_cost is null or gift_cost <> p_cost then raise exception 'Invalid gift'; end if;
 update public.profiles set stars=stars-gift_cost where id=sender and stars>=gift_cost;
 if not found then raise exception 'Not enough stars'; end if;
 insert into public.gift_inventory(owner_id,gift_id,gift_name,sender_id)
 values(p_recipient_id,p_gift_id,p_gift_name,sender) returning id into inventory_id;
 return inventory_id;
end; $$;
revoke all on function public.send_gift(uuid,text,text,integer) from public;
grant execute on function public.send_gift(uuid,text,text,integer) to authenticated;
-- Storage buckets: create avatars (public) and voice (private) in Supabase Storage.


-- Developer/admin privileges. The password is managed ONLY by Supabase Auth.
-- This allowlist grants admin status to the specified verified login email.
alter table public.profiles add column if not exists is_admin boolean not null default false;\nalter table public.gift_inventory add column if not exists gift_emoji text;
update public.profiles p set is_admin=true
from auth.users u where p.id=u.id and lower(u.email)='vzwipp@gmail.com';
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare uname text;
begin
 uname := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)),'[^a-zA-Z0-9_]','','g')) || '_' || substr(new.id::text,1,6);
 insert into public.profiles(id,username,display_name,stars,is_admin)
 values(new.id,uname,coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)),100,lower(new.email)='vzwipp@gmail.com');
 return new;
end; $$;
create or replace function public.admin_grant_stars(p_user_id uuid,p_amount integer)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and is_admin=true) then raise exception 'Admin only'; end if;
 if p_amount is null or p_amount<1 or p_amount>100000000 then raise exception 'Invalid amount'; end if;
 update public.profiles set stars=stars+p_amount where id=p_user_id;
 if not found then raise exception 'User not found'; end if;
end; $$;
create or replace function public.admin_give_gift(p_user_id uuid,p_gift_id text,p_gift_name text,p_emoji text)
returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid;
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and is_admin=true) then raise exception 'Admin only'; end if;
 if p_gift_id is null or length(p_gift_id)>80 or p_gift_name is null or length(p_gift_name)>120 then raise exception 'Invalid gift'; end if;
 insert into public.gift_inventory(owner_id,gift_id,gift_name,sender_id)
 values(p_user_id,p_gift_id,p_gift_name,auth.uid()) returning id into new_id;
 return new_id;
end; $$;
revoke all on function public.admin_grant_stars(uuid,integer) from public;
revoke all on function public.admin_give_gift(uuid,text,text,text) from public;
grant execute on function public.admin_grant_stars(uuid,integer) to authenticated;
grant execute on function public.admin_give_gift(uuid,text,text,text) to authenticated;
