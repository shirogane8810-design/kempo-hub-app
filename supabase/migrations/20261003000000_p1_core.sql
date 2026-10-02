-- =====================================================================
-- kempo-hub-app P1（新人戦版）のコアスキーマ
-- 仕様: docs/spec.md 「6. データ設計」「7. 権限とセキュリティ」
--
-- 原則
-- - 全テーブルに organization_id（主催団体）を持たせる（P4 の他団体提供に備える）
-- - 全テーブルで RLS を有効にする。ポリシーのないテーブルは誰も読めない
-- - 試合結果は match_events（採点記録）が正。match_events は追記のみ（更新・削除不可）
-- - 公開画面向けの読み取りは、個人情報を含まない view を通す
-- - P2 以降のテーブル（団体戦、ランキング、賛助会員など）は別マイグレーションで追加する
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 主催団体と役割
-- ---------------------------------------------------------------------
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null default 'association',
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  email text,
  is_system_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('org_admin', 'staff')),
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

-- ---------------------------------------------------------------------
-- 権限判定の関数（RLS から使う）
-- security definer にして、判定のための参照が RLS で再帰しないようにする
-- ---------------------------------------------------------------------
create or replace function public.is_system_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select p.is_system_admin from public.profiles p where p.id = auth.uid()), false)
$$;

create or replace function public.has_org_role(org uuid, roles text[])
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_system_admin() or exists (
    select 1 from public.memberships m
    where m.organization_id = org and m.user_id = auth.uid() and m.role = any (roles)
  )
$$;

create or replace function public.is_org_admin(org uuid)
returns boolean language sql stable as $$ select public.has_org_role(org, array['org_admin']) $$;

create or replace function public.is_org_staff(org uuid)
returns boolean language sql stable as $$ select public.has_org_role(org, array['org_admin', 'staff']) $$;

-- ---------------------------------------------------------------------
-- 大学・道場と選手
-- ---------------------------------------------------------------------
create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  kind text not null default 'university' check (kind in ('university', 'dojo', 'other')),
  description text,
  practice_place text,
  invite_code text not null default encode(gen_random_bytes(9), 'base64'),
  created_at timestamptz not null default now()
);

create table public.club_reps (
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  primary key (club_id, user_id)
);

create or replace function public.is_club_rep(club uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.club_reps r where r.club_id = club and r.user_id = auth.uid())
$$;

create table public.athletes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  club_id uuid not null references public.clubs (id) on delete restrict,
  user_id uuid references auth.users (id) on delete set null, -- ログインする本人との紐づけ（任意）
  name text not null,
  name_kana text not null default '',
  grade text,
  rank text,
  photo_path text,
  is_photo_public boolean not null default false,
  is_grade_public boolean not null default false,
  created_at timestamptz not null default now()
);
create index on public.athletes (club_id);
create index on public.athletes (user_id);

-- ---------------------------------------------------------------------
-- 大会・ルール・部門・コート
-- ---------------------------------------------------------------------
create table public.rule_sets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  -- 値は審判部と確定して管理画面から入れる。コードに書き込まない
  points_to_win int not null check (points_to_win > 0),
  duration_sec int not null check (duration_sec > 0),
  extension_sec int not null default 0 check (extension_sec >= 0),
  fouls_per_point int check (fouls_per_point is null or fouls_per_point > 0),
  created_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  slug text not null unique,
  name text not null,
  starts_on date not null,
  ends_on date,
  venue text,
  entry_opens_at timestamptz,
  entry_closes_at timestamptz,
  status text not null default 'draft' check (status in ('draft', 'published', 'live', 'finished')),
  guideline_pdf_path text,
  notify_before_matches int not null default 2 check (notify_before_matches >= 0),
  created_at timestamptz not null default now()
);

create or replace function public.is_event_public(ev uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.events e where e.id = ev and e.status <> 'draft')
$$;

create or replace function public.is_entry_open(ev uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.events e
    where e.id = ev and e.status <> 'draft'
      and (e.entry_opens_at is null or e.entry_opens_at <= now())
      and (e.entry_closes_at is null or now() < e.entry_closes_at)
  )
$$;

create table public.divisions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  event_id uuid not null references public.events (id) on delete cascade,
  name text not null,
  kind text not null default 'individual' check (kind in ('individual', 'team')),
  conditions jsonb not null default '{}'::jsonb, -- 男女・段級などの条件
  team_size int check (team_size is null or team_size > 0),
  rule_set_id uuid references public.rule_sets (id),
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index on public.divisions (event_id);

create table public.courts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  event_id uuid not null references public.events (id) on delete cascade,
  name text not null,
  stream_url text,
  sort_order int not null default 0
);
create index on public.courts (event_id);

-- 審判用 PIN は公開されるテーブルと分けて保存する（ハッシュのみ）
create table public.court_secrets (
  court_id uuid primary key references public.courts (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  pin_hash text not null,
  failed_attempts int not null default 0,
  locked_until timestamptz
);

-- PIN を確認した端末（匿名ログインのユーザー）に、コートへの採点権を一定時間与える
-- 付与は Edge Function（verify-court-pin）が service role で行う
create table public.court_grants (
  court_id uuid not null references public.courts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  expires_at timestamptz not null,
  primary key (court_id, user_id)
);

create or replace function public.has_court_grant(court uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.court_grants g
    where g.court_id = court and g.user_id = auth.uid() and g.expires_at > now()
  )
$$;

create table public.referees (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  license text
);

create table public.referee_assignments (
  referee_id uuid not null references public.referees (id) on delete cascade,
  court_id uuid not null references public.courts (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  role text not null default 'chief' check (role in ('chief', 'sub')),
  starts_at timestamptz,
  ends_at timestamptz,
  primary key (referee_id, court_id)
);

-- ---------------------------------------------------------------------
-- エントリー
-- ---------------------------------------------------------------------
create table public.entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  division_id uuid not null references public.divisions (id) on delete cascade,
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'withdrawn')),
  seed int check (seed is null or seed > 0),
  paid_reported_at timestamptz, -- 代表者が「振込済み」と申告
  paid_confirmed_at timestamptz, -- 運営が確認（決済機能は持たない）
  checked_in_at timestamptz,
  checkin_token text not null default encode(gen_random_bytes(12), 'hex'),
  created_at timestamptz not null default now(),
  unique (division_id, athlete_id)
);
create index on public.entries (athlete_id);

-- ---------------------------------------------------------------------
-- トーナメントと試合
-- ---------------------------------------------------------------------
create table public.brackets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  division_id uuid not null unique references public.divisions (id) on delete cascade,
  format text not null default 'single_elimination',
  random_seed int not null default 1,
  locked boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  bracket_id uuid not null references public.brackets (id) on delete cascade,
  round int not null check (round > 0),
  slot int not null check (slot >= 0),
  red_entry_id uuid references public.entries (id),
  white_entry_id uuid references public.entries (id),
  winner_entry_id uuid references public.entries (id),
  win_reason text check (win_reason in ('points', 'decision', 'walkover')),
  next_match_id uuid references public.matches (id),
  next_side text check (next_side in ('red', 'white')),
  court_id uuid references public.courts (id),
  order_on_court int,
  scheduled_at timestamptz,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'called', 'running', 'finished', 'bye')),
  updated_at timestamptz not null default now(),
  unique (bracket_id, round, slot)
);
create index on public.matches (court_id, order_on_court);

create or replace function public.match_event_id(m uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select d.event_id from public.matches x
  join public.brackets b on b.id = x.bracket_id
  join public.divisions d on d.id = b.division_id
  where x.id = m
$$;

create or replace function public.match_court_id(m uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select court_id from public.matches where id = m
$$;

-- 採点記録。追記のみ。取り消しも type='undo' の記録で表す
create table public.match_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  match_id uuid not null references public.matches (id) on delete cascade,
  seq int not null check (seq > 0),
  type text not null check (type in ('start', 'stop', 'point', 'foul', 'decision', 'walkover', 'undo', 'confirm')),
  side text check (side in ('red', 'white')),
  target_seq int,
  at timestamptz not null,
  device_id text not null,
  created_by uuid default auth.uid(),
  received_at timestamptz not null default now(),
  unique (match_id, seq),
  check ((type in ('point', 'foul', 'decision', 'walkover')) = (side is not null)),
  check ((type = 'undo') = (target_seq is not null))
);
create index on public.match_events (match_id, seq);

-- 公開画面向けの軽いデータ（観客は30秒ごとにこれだけを取得する）
create table public.live_snapshots (
  event_id uuid primary key references public.events (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- お知らせ・通知
-- ---------------------------------------------------------------------
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  event_id uuid references public.events (id) on delete cascade,
  title text not null,
  body text not null default '',
  is_public boolean not null default true,
  send_push boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now()
);

-- 通知の宛先。ログインなしの端末も登録できるが、書き込みは Edge Function（service role）経由のみ
create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  endpoint text not null unique,
  keys jsonb not null,
  user_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.follows (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.push_subscriptions (id) on delete cascade,
  athlete_id uuid references public.athletes (id) on delete cascade,
  club_id uuid references public.clubs (id) on delete cascade,
  notify_before int, -- null なら大会の既定値
  created_at timestamptz not null default now(),
  check ((athlete_id is null) <> (club_id is null))
);

create table public.notification_log (
  id bigint generated always as identity primary key,
  subscription_id uuid not null references public.push_subscriptions (id) on delete cascade,
  match_id uuid references public.matches (id) on delete cascade,
  kind text not null,
  sent_at timestamptz not null default now(),
  unique (subscription_id, match_id, kind)
);

-- ---------------------------------------------------------------------
-- 協賛・広告
-- ---------------------------------------------------------------------
create table public.sponsors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  logo_path text,
  link_url text,
  report_key text not null default encode(gen_random_bytes(18), 'hex'),
  created_at timestamptz not null default now()
);

create table public.ad_slots (
  id text primary key, -- 'top', 'event', 'bracket_bottom', 'courts'
  label text not null,
  width int,
  height int
);

create table public.ad_placements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  sponsor_id uuid not null references public.sponsors (id) on delete cascade,
  slot_id text not null references public.ad_slots (id),
  event_id uuid references public.events (id) on delete cascade, -- null なら全ページ
  image_path text not null,
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now(),
  check (starts_on <= ends_on)
);

create table public.ad_stats_daily (
  placement_id uuid not null references public.ad_placements (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  day date not null,
  impressions int not null default 0,
  clicks int not null default 0,
  primary key (placement_id, day)
);

-- 表示・クリックの記録（誰でも呼べるが、集計行を1つ増やすだけ）
create or replace function public.record_ad_event(placement uuid, kind text)
returns void language plpgsql security definer set search_path = public as $$
declare org uuid;
begin
  if kind not in ('impression', 'click') then raise exception 'invalid kind'; end if;
  select organization_id into org from public.ad_placements
    where id = placement and current_date between starts_on and ends_on;
  if org is null then return; end if;
  insert into public.ad_stats_daily (placement_id, organization_id, day, impressions, clicks)
  values (placement, org, current_date, (kind = 'impression')::int, (kind = 'click')::int)
  on conflict (placement_id, day) do update
    set impressions = ad_stats_daily.impressions + excluded.impressions,
        clicks = ad_stats_daily.clicks + excluded.clicks;
end $$;

-- ---------------------------------------------------------------------
-- 操作履歴
-- ---------------------------------------------------------------------
create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid,
  actor uuid default auth.uid(),
  table_name text not null,
  row_id text,
  action text not null,
  before jsonb,
  after jsonb,
  at timestamptz not null default now()
);

create or replace function public.audit_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs (organization_id, table_name, row_id, action, before, after)
  values (
    coalesce((to_jsonb(new) ->> 'organization_id')::uuid, (to_jsonb(old) ->> 'organization_id')::uuid),
    tg_table_name,
    coalesce(to_jsonb(new) ->> 'id', to_jsonb(old) ->> 'id'),
    tg_op,
    case when tg_op <> 'INSERT' then to_jsonb(old) end,
    case when tg_op <> 'DELETE' then to_jsonb(new) end
  );
  return coalesce(new, old);
end $$;

-- 結果の修正・権限の変更・削除を必ず記録する
create trigger audit_matches after update or delete on public.matches
  for each row execute function public.audit_trigger();
create trigger audit_memberships after insert or update or delete on public.memberships
  for each row execute function public.audit_trigger();
create trigger audit_entries after update or delete on public.entries
  for each row execute function public.audit_trigger();
create trigger audit_events after delete on public.events
  for each row execute function public.audit_trigger();

-- =====================================================================
-- 公開用の view（個人情報を含まない）。所有者権限で動き、公開中の大会だけを出す
-- =====================================================================
create view public.public_athletes as
  select a.id, a.organization_id, a.club_id, a.name, a.name_kana,
         case when a.is_grade_public then a.grade end as grade,
         case when a.is_photo_public then a.photo_path end as photo_path
  from public.athletes a;

create view public.public_entries as
  select e.id, e.division_id, e.athlete_id, e.seed
  from public.entries e
  join public.divisions d on d.id = e.division_id
  where e.status = 'approved' and public.is_event_public(d.event_id);

-- =====================================================================
-- RLS
-- =====================================================================
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.clubs enable row level security;
alter table public.club_reps enable row level security;
alter table public.athletes enable row level security;
alter table public.rule_sets enable row level security;
alter table public.events enable row level security;
alter table public.divisions enable row level security;
alter table public.courts enable row level security;
alter table public.court_secrets enable row level security;
alter table public.court_grants enable row level security;
alter table public.referees enable row level security;
alter table public.referee_assignments enable row level security;
alter table public.entries enable row level security;
alter table public.brackets enable row level security;
alter table public.matches enable row level security;
alter table public.match_events enable row level security;
alter table public.live_snapshots enable row level security;
alter table public.announcements enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.follows enable row level security;
alter table public.notification_log enable row level security;
alter table public.sponsors enable row level security;
alter table public.ad_slots enable row level security;
alter table public.ad_placements enable row level security;
alter table public.ad_stats_daily enable row level security;
alter table public.audit_logs enable row level security;

-- 主催団体・所属：誰でも読める
create policy org_read on public.organizations for select using (true);
create policy org_admin_write on public.organizations for all
  using (public.is_system_admin()) with check (public.is_system_admin());

-- プロフィール：本人と運営
create policy profiles_self on public.profiles for select using (id = auth.uid() or public.is_system_admin());
create policy profiles_self_upsert on public.profiles for insert with check (id = auth.uid() and is_system_admin = false);
create policy profiles_self_update on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid() and is_system_admin = (select p.is_system_admin from public.profiles p where p.id = auth.uid()));

-- 役割：本人は自分の役割を読める。付与・変更は団体の管理者
create policy memberships_read on public.memberships for select
  using (user_id = auth.uid() or public.is_org_admin(organization_id));
create policy memberships_write on public.memberships for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

-- 大学・道場：誰でも読める（招待コードは view を作らず、管理者と代表だけが参照する運用）
create policy clubs_read on public.clubs for select using (true);
create policy clubs_admin on public.clubs for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));
create policy clubs_rep_update on public.clubs for update
  using (public.is_club_rep(id)) with check (public.is_club_rep(id));

create policy club_reps_read on public.club_reps for select
  using (user_id = auth.uid() or public.is_org_staff(organization_id));
create policy club_reps_admin on public.club_reps for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

-- 選手：基本テーブルは本人・所属の代表・運営だけ。公開は public_athletes view
create policy athletes_read on public.athletes for select
  using (user_id = auth.uid() or public.is_club_rep(club_id) or public.is_org_staff(organization_id));
create policy athletes_rep_insert on public.athletes for insert
  with check (public.is_club_rep(club_id) or public.is_org_admin(organization_id));
create policy athletes_update on public.athletes for update
  using (user_id = auth.uid() or public.is_club_rep(club_id) or public.is_org_admin(organization_id))
  with check (user_id = auth.uid() or public.is_club_rep(club_id) or public.is_org_admin(organization_id));
create policy athletes_admin_delete on public.athletes for delete using (public.is_org_admin(organization_id));

-- ルール・大会・部門・コート：公開中の大会は誰でも読める。書き込みは管理者
create policy rule_sets_read on public.rule_sets for select using (true);
create policy rule_sets_admin on public.rule_sets for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

create policy events_read on public.events for select
  using (status <> 'draft' or public.is_org_staff(organization_id));
create policy events_admin on public.events for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

create policy divisions_read on public.divisions for select
  using (public.is_event_public(event_id) or public.is_org_staff(organization_id));
create policy divisions_admin on public.divisions for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

create policy courts_read on public.courts for select
  using (public.is_event_public(event_id) or public.is_org_staff(organization_id));
create policy courts_admin on public.courts for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

-- PIN と採点権：画面からは読めない・書けない（Edge Function が service role で扱う）
create policy court_grants_self on public.court_grants for select using (user_id = auth.uid());

create policy referees_staff on public.referees for select using (public.is_org_staff(organization_id));
create policy referees_admin on public.referees for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));
create policy referee_assignments_staff on public.referee_assignments for select using (public.is_org_staff(organization_id));
create policy referee_assignments_admin on public.referee_assignments for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

-- エントリー：基本テーブルは本人・所属の代表・運営。公開は public_entries view
create policy entries_read on public.entries for select
  using (
    public.is_org_staff(organization_id)
    or exists (select 1 from public.athletes a where a.id = athlete_id
               and (a.user_id = auth.uid() or public.is_club_rep(a.club_id)))
  );
-- 代表者は受付期間中だけ自分の所属の選手を申し込める
create policy entries_rep_insert on public.entries for insert
  with check (
    status = 'pending' and paid_confirmed_at is null and checked_in_at is null and seed is null
    and exists (select 1 from public.athletes a where a.id = athlete_id and public.is_club_rep(a.club_id))
    and exists (select 1 from public.divisions d where d.id = division_id and public.is_entry_open(d.event_id))
  );
create policy entries_staff_write on public.entries for all
  using (public.is_org_staff(organization_id)) with check (public.is_org_staff(organization_id));

-- 代表者の更新は「振込済みの申告」だけに限る（列の制限はトリガーで行う）
create policy entries_rep_update on public.entries for update
  using (exists (select 1 from public.athletes a where a.id = athlete_id and public.is_club_rep(a.club_id)))
  with check (exists (select 1 from public.athletes a where a.id = athlete_id and public.is_club_rep(a.club_id)));

create or replace function public.entries_rep_guard()
returns trigger language plpgsql as $$
begin
  if public.is_org_staff(new.organization_id) then return new; end if;
  if new.division_id <> old.division_id or new.athlete_id <> old.athlete_id
     or new.status is distinct from old.status or new.seed is distinct from old.seed
     or new.paid_confirmed_at is distinct from old.paid_confirmed_at
     or new.checked_in_at is distinct from old.checked_in_at
     or new.checkin_token <> old.checkin_token then
    raise exception '代表者が変更できるのは入金の申告だけです';
  end if;
  return new;
end $$;
create trigger entries_rep_guard before update on public.entries
  for each row execute function public.entries_rep_guard();

-- トーナメント・試合：公開中の大会は誰でも読める。書き込みは運営（当日スタッフも可）
create policy brackets_read on public.brackets for select
  using (public.is_org_staff(organization_id) or exists (
    select 1 from public.divisions d where d.id = division_id and public.is_event_public(d.event_id)));
create policy brackets_admin on public.brackets for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

create policy matches_read on public.matches for select
  using (public.is_org_staff(organization_id) or public.is_event_public(public.match_event_id(id))
         or public.has_court_grant(court_id));
create policy matches_staff on public.matches for all
  using (public.is_org_staff(organization_id)) with check (public.is_org_staff(organization_id));

-- 採点記録：読むのは公開中なら誰でも。書くのは担当コートの採点権がある端末か運営。更新・削除は不可
create policy match_events_read on public.match_events for select
  using (public.is_org_staff(organization_id) or public.is_event_public(public.match_event_id(match_id))
         or public.has_court_grant(public.match_court_id(match_id)));
create policy match_events_insert on public.match_events for insert
  with check (
    public.is_org_staff(organization_id)
    or (public.has_court_grant(public.match_court_id(match_id))
        and not exists (select 1 from public.matches m where m.id = match_id and m.status = 'finished'))
  );

create policy live_snapshots_read on public.live_snapshots for select using (public.is_event_public(event_id));
create policy live_snapshots_staff on public.live_snapshots for all
  using (public.is_org_staff(organization_id)) with check (public.is_org_staff(organization_id));

create policy announcements_read on public.announcements for select
  using ((is_public and published_at is not null and published_at <= now()) or public.is_org_staff(organization_id));
create policy announcements_admin on public.announcements for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

-- push_subscriptions / follows / notification_log：ポリシーなし（Edge Function のみが扱う）

create policy sponsors_staff on public.sponsors for select using (public.is_org_staff(organization_id));
create policy sponsors_admin on public.sponsors for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

create policy ad_slots_read on public.ad_slots for select using (true);

-- 掲載中の広告は誰でも読める（画像とリンク先を出すため）
create policy ad_placements_read on public.ad_placements for select
  using (current_date between starts_on and ends_on or public.is_org_staff(organization_id));
create policy ad_placements_admin on public.ad_placements for all
  using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

create policy ad_stats_staff on public.ad_stats_daily for select using (public.is_org_staff(organization_id));

create policy audit_logs_admin on public.audit_logs for select using (public.is_org_admin(organization_id));

-- 広告の公開用 view（スポンサー名とリンク先だけ）
create view public.public_ads as
  select p.id, p.slot_id, p.event_id, p.image_path, s.name as sponsor_name, s.link_url
  from public.ad_placements p join public.sponsors s on s.id = p.sponsor_id
  where current_date between p.starts_on and p.ends_on;

-- =====================================================================
-- 権限（GRANT）。RLS と組み合わせて効く
-- =====================================================================
grant usage on schema public to anon, authenticated;
grant select on all tables in schema public to anon, authenticated;
grant insert, update, delete on all tables in schema public to authenticated;
revoke all on public.court_secrets, public.push_subscriptions, public.follows, public.notification_log
  from anon, authenticated;
revoke insert, update, delete on public.audit_logs, public.ad_stats_daily from authenticated;
revoke update, delete on public.match_events from authenticated;
grant execute on function public.record_ad_event(uuid, text) to anon, authenticated;

-- 初期データ：広告枠
insert into public.ad_slots (id, label) values
  ('top', 'トップ'),
  ('event', '大会ページ'),
  ('bracket_bottom', 'トーナメント表の下'),
  ('courts', 'コート別の進行');
