create extension if not exists pgcrypto;

create type public.user_role as enum ('PLAYER','ADMIN');
create type public.request_status as enum ('PENDING','APPROVED','PAID','REJECTED','CANCELLED');
create type public.tx_type as enum ('DEPOSIT','WITHDRAWAL','BET','WIN','REFUND','BONUS','ADMIN_ADJUSTMENT');

create table public.users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  legal_name text not null,
  ingame_first_name text not null,
  ingame_last_name text not null,
  fivem_id text,
  password_hash text not null,
  role public.user_role not null default 'PLAYER',
  is_frozen boolean not null default false,
  created_at timestamptz not null default now(),
  last_login_at timestamptz
);

create table public.wallets (
  user_id uuid primary key references public.users(id) on delete cascade,
  available_balance bigint not null default 0 check (available_balance >= 0),
  reserved_balance bigint not null default 0 check (reserved_balance >= 0),
  total_deposited bigint not null default 0,
  total_withdrawn bigint not null default 0,
  total_wagered bigint not null default 0,
  total_won bigint not null default 0,
  version bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table public.access_codes (
  id uuid primary key default gen_random_uuid(),
  registration_code text not null unique,
  verification_code text not null,
  fivem_id text,
  active boolean not null default true,
  used_by uuid references public.users(id),
  used_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index access_code_pair on public.access_codes(registration_code, verification_code);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type public.tx_type not null,
  amount bigint not null,
  balance_before bigint not null,
  balance_after bigint not null,
  reference_type text,
  reference_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index transactions_user_created_idx on public.transactions(user_id, created_at desc);

create table public.deposit_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  amount bigint not null check (amount > 0),
  fivem_id text not null,
  note text,
  status public.request_status not null default 'PENDING',
  processed_by uuid references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  amount bigint not null check (amount > 0),
  fivem_id text not null,
  status public.request_status not null default 'PENDING',
  processed_by uuid references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.game_rounds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  game_key text not null,
  wager bigint not null check (wager > 0),
  payout bigint not null default 0 check (payout >= 0),
  outcome jsonb not null,
  created_at timestamptz not null default now()
);

create table public.game_config (
  game_key text primary key,
  enabled boolean not null default true,
  min_bet bigint not null default 100,
  max_bet bigint not null default 100000,
  max_payout bigint not null default 1000000,
  rtp_basis_points integer not null default 9400 check (rtp_basis_points between 9000 and 9800),
  updated_at timestamptz not null default now()
);

insert into public.game_config(game_key,min_bet,max_bet,max_payout,rtp_basis_points) values
  ('slots',100,100000,1000000,9400),
  ('roulette',100,100000,3500000,9729),
  ('dice',100,100000,1000000,9600)
on conflict do nothing;

create table public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.users(id),
  action text not null,
  target_type text,
  target_id uuid,
  before_data jsonb,
  after_data jsonb,
  reason text,
  created_at timestamptz not null default now()
);

-- Registration is atomic: consume the pair once and create wallet once.
create or replace function public.register_player(
  p_username text,
  p_legal_name text,
  p_ingame_first_name text,
  p_ingame_last_name text,
  p_fivem_id text,
  p_password_hash text,
  p_registration_code text,
  p_verification_code text
) returns public.users
language plpgsql security definer set search_path = public as $$
declare
  c public.access_codes;
  u public.users;
begin
  select * into c from public.access_codes
    where registration_code = upper(trim(p_registration_code))
      and verification_code = upper(trim(p_verification_code))
      and active = true and used_by is null
      and (expires_at is null or expires_at > now())
    for update;
  if not found then raise exception 'INVALID_CODES'; end if;
  if c.fivem_id is not null and c.fivem_id <> trim(p_fivem_id) then raise exception 'FIVEM_MISMATCH'; end if;

  insert into public.users(username, legal_name, ingame_first_name, ingame_last_name, fivem_id, password_hash)
  values (lower(trim(p_username)), trim(p_legal_name), trim(p_ingame_first_name), trim(p_ingame_last_name), trim(p_fivem_id), p_password_hash)
  returning * into u;
  insert into public.wallets(user_id) values (u.id);
  update public.access_codes set used_by=u.id, used_at=now(), active=false where id=c.id;
  return u;
end $$;

create or replace function public.settle_game_round(
  p_user_id uuid,
  p_game_key text,
  p_wager bigint,
  p_payout bigint,
  p_outcome jsonb
) returns table(round_id uuid, balance bigint)
language plpgsql security definer set search_path = public as $$
declare
  w public.wallets;
  cfg public.game_config;
  rid uuid;
begin
  select * into cfg from public.game_config where game_key=p_game_key;
  if not found or not cfg.enabled then raise exception 'GAME_DISABLED'; end if;
  if p_wager < cfg.min_bet or p_wager > cfg.max_bet then raise exception 'BET_LIMIT'; end if;
  if p_payout > cfg.max_payout then raise exception 'PAYOUT_LIMIT'; end if;
  if exists(select 1 from public.users where id=p_user_id and is_frozen=true) then raise exception 'ACCOUNT_FROZEN'; end if;

  select * into w from public.wallets where user_id=p_user_id for update;
  if w.available_balance < p_wager then raise exception 'INSUFFICIENT_BALANCE'; end if;

  insert into public.game_rounds(user_id, game_key, wager, payout, outcome)
  values(p_user_id,p_game_key,p_wager,p_payout,p_outcome) returning id into rid;

  insert into public.transactions(user_id,type,amount,balance_before,balance_after,reference_type,reference_id)
  values(p_user_id,'BET',-p_wager,w.available_balance,w.available_balance-p_wager,'GAME_ROUND',rid);

  update public.wallets set available_balance=available_balance-p_wager,
    total_wagered=total_wagered+p_wager, version=version+1, updated_at=now() where user_id=p_user_id;

  if p_payout > 0 then
    insert into public.transactions(user_id,type,amount,balance_before,balance_after,reference_type,reference_id)
    values(p_user_id,'WIN',p_payout,w.available_balance-p_wager,w.available_balance-p_wager+p_payout,'GAME_ROUND',rid);
    update public.wallets set available_balance=available_balance+p_payout,
      total_won=total_won+p_payout, version=version+1, updated_at=now() where user_id=p_user_id;
  end if;

  return query select rid, wa.available_balance from public.wallets wa where wa.user_id=p_user_id;
end $$;

create or replace function public.create_withdrawal(p_user_id uuid, p_amount bigint)
returns public.withdrawal_requests
language plpgsql security definer set search_path=public as $$
declare
  w public.wallets;
  u public.users;
  r public.withdrawal_requests;
begin
  if p_amount <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  select * into u from public.users where id=p_user_id;
  if not found or u.is_frozen then raise exception 'ACCOUNT_FROZEN'; end if;
  if u.fivem_id is null or length(trim(u.fivem_id))=0 then raise exception 'FIVEM_REQUIRED'; end if;
  select * into w from public.wallets where user_id=p_user_id for update;
  if w.available_balance < p_amount then raise exception 'INSUFFICIENT_BALANCE'; end if;

  update public.wallets set available_balance=available_balance-p_amount,
    reserved_balance=reserved_balance+p_amount, version=version+1, updated_at=now() where user_id=p_user_id;
  insert into public.withdrawal_requests(user_id,amount,fivem_id) values(p_user_id,p_amount,u.fivem_id) returning * into r;
  insert into public.transactions(user_id,type,amount,balance_before,balance_after,reference_type,reference_id,metadata)
    values(p_user_id,'WITHDRAWAL',-p_amount,w.available_balance,w.available_balance-p_amount,'WITHDRAWAL',r.id,jsonb_build_object('status','RESERVED'));
  return r;
end $$;

create or replace function public.admin_approve_deposit(p_admin uuid, p_request uuid)
returns bigint language plpgsql security definer set search_path=public as $$
declare d public.deposit_requests; w public.wallets; nb bigint;
begin
  if not exists(select 1 from public.users where id=p_admin and role='ADMIN') then raise exception 'FORBIDDEN'; end if;
  select * into d from public.deposit_requests where id=p_request for update;
  if not found or d.status <> 'PENDING' then raise exception 'NOT_PENDING'; end if;
  select * into w from public.wallets where user_id=d.user_id for update;
  nb := w.available_balance + d.amount;
  update public.wallets set available_balance=nb,total_deposited=total_deposited+d.amount,version=version+1,updated_at=now() where user_id=d.user_id;
  update public.deposit_requests set status='APPROVED',processed_by=p_admin,updated_at=now() where id=d.id;
  insert into public.transactions(user_id,type,amount,balance_before,balance_after,reference_type,reference_id)
    values(d.user_id,'DEPOSIT',d.amount,w.available_balance,nb,'DEPOSIT',d.id);
  insert into public.admin_audit_logs(admin_id,action,target_type,target_id,after_data)
    values(p_admin,'DEPOSIT_APPROVED','DEPOSIT',d.id,jsonb_build_object('amount',d.amount));
  return nb;
end $$;

create or replace function public.admin_reject_deposit(p_admin uuid, p_request uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from public.users where id=p_admin and role='ADMIN') then raise exception 'FORBIDDEN'; end if;
  update public.deposit_requests set status='REJECTED',processed_by=p_admin,updated_at=now() where id=p_request and status='PENDING';
  if not found then raise exception 'NOT_PENDING'; end if;
  insert into public.admin_audit_logs(admin_id,action,target_type,target_id) values(p_admin,'DEPOSIT_REJECTED','DEPOSIT',p_request);
end $$;

create or replace function public.admin_withdrawal_action(p_admin uuid,p_request uuid,p_action text)
returns void language plpgsql security definer set search_path=public as $$
declare r public.withdrawal_requests; w public.wallets;
begin
  if not exists(select 1 from public.users where id=p_admin and role='ADMIN') then raise exception 'FORBIDDEN'; end if;
  select * into r from public.withdrawal_requests where id=p_request for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  select * into w from public.wallets where user_id=r.user_id for update;

  if p_action='APPROVE' then
    if r.status <> 'PENDING' then raise exception 'INVALID_STATUS'; end if;
    update public.withdrawal_requests set status='APPROVED',processed_by=p_admin,updated_at=now() where id=r.id;
  elsif p_action='PAID' then
    if r.status not in ('PENDING','APPROVED') then raise exception 'INVALID_STATUS'; end if;
    update public.wallets set reserved_balance=reserved_balance-r.amount,total_withdrawn=total_withdrawn+r.amount,version=version+1,updated_at=now() where user_id=r.user_id;
    update public.withdrawal_requests set status='PAID',processed_by=p_admin,updated_at=now() where id=r.id;
  elsif p_action='REJECT' then
    if r.status not in ('PENDING','APPROVED') then raise exception 'INVALID_STATUS'; end if;
    update public.wallets set available_balance=available_balance+r.amount,reserved_balance=reserved_balance-r.amount,version=version+1,updated_at=now() where user_id=r.user_id;
    update public.withdrawal_requests set status='REJECTED',processed_by=p_admin,updated_at=now() where id=r.id;
    insert into public.transactions(user_id,type,amount,balance_before,balance_after,reference_type,reference_id)
      values(r.user_id,'REFUND',r.amount,w.available_balance,w.available_balance+r.amount,'WITHDRAWAL',r.id);
  else raise exception 'INVALID_ACTION';
  end if;
  insert into public.admin_audit_logs(admin_id,action,target_type,target_id,after_data)
    values(p_admin,'WITHDRAWAL_'||p_action,'WITHDRAWAL',r.id,jsonb_build_object('amount',r.amount));
end $$;

create or replace function public.admin_adjust_balance(p_admin uuid,p_user uuid,p_amount bigint,p_reason text)
returns bigint language plpgsql security definer set search_path=public as $$
declare w public.wallets; nb bigint;
begin
  if not exists(select 1 from public.users where id=p_admin and role='ADMIN') then raise exception 'FORBIDDEN'; end if;
  if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'REASON_REQUIRED'; end if;
  select * into w from public.wallets where user_id=p_user for update;
  nb := w.available_balance + p_amount;
  if nb < 0 then raise exception 'NEGATIVE_BALANCE'; end if;
  update public.wallets set available_balance=nb,version=version+1,updated_at=now() where user_id=p_user;
  insert into public.transactions(user_id,type,amount,balance_before,balance_after,metadata)
    values(p_user,'ADMIN_ADJUSTMENT',p_amount,w.available_balance,nb,jsonb_build_object('reason',p_reason,'admin',p_admin));
  insert into public.admin_audit_logs(admin_id,action,target_type,target_id,before_data,after_data,reason)
    values(p_admin,'BALANCE_ADJUSTMENT','USER',p_user,jsonb_build_object('balance',w.available_balance),jsonb_build_object('balance',nb),p_reason);
  return nb;
end $$;

-- Service-role-only app: disable public API access to all tables by default.
alter table public.users enable row level security;
alter table public.wallets enable row level security;
alter table public.access_codes enable row level security;
alter table public.transactions enable row level security;
alter table public.deposit_requests enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.game_rounds enable row level security;
alter table public.game_config enable row level security;
alter table public.admin_audit_logs enable row level security;
