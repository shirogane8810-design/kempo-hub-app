-- RLS（権限）のテスト。仕様: docs/spec.md 「7. 権限とセキュリティ」
-- 実行: npm run test:db（素の PostgreSQL に stub_supabase.sql とマイグレーションを流してから実行）
-- 失敗すると例外で止まる。最後に「RLS tests passed」と表示されれば合格。
\set ON_ERROR_STOP on

-- ------------------------------------------------------------------
-- テストデータ（service role 相当＝RLS を通さずに作る）
-- ------------------------------------------------------------------
insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000000a'), -- 管理者
  ('00000000-0000-0000-0000-00000000000b'), -- 大学Aの代表
  ('00000000-0000-0000-0000-00000000000c'), -- 大学Bの代表
  ('00000000-0000-0000-0000-00000000000d'), -- 審判端末（コート1）
  ('00000000-0000-0000-0000-00000000000e'); -- 選手本人（大学A）

insert into public.organizations (id, name) values ('10000000-0000-0000-0000-000000000001', 'NIKKEN NEXT');
insert into public.memberships (organization_id, user_id, role)
  values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'org_admin');

insert into public.clubs (id, organization_id, name) values
  ('20000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000001', '大学A'),
  ('20000000-0000-0000-0000-00000000000b', '10000000-0000-0000-0000-000000000001', '大学B');
insert into public.club_reps (club_id, user_id, organization_id) values
  ('20000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', '10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000001');

insert into public.athletes (id, organization_id, club_id, name, grade, user_id) values
  ('30000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-00000000000a', '選手A', '1年', '00000000-0000-0000-0000-00000000000e'),
  ('30000000-0000-0000-0000-00000000000b', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-00000000000b', '選手B', '2年', null);

insert into public.rule_sets (id, organization_id, name, points_to_win, duration_sec)
  values ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'テスト用', 2, 120);

insert into public.events (id, organization_id, slug, name, starts_on, status, entry_closes_at) values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'shinjin-2026', '全国新人戦', '2026-12-13', 'published', now() + interval '10 days'),
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'draft-event', '下書き大会', '2027-01-01', 'draft', null);

insert into public.divisions (id, organization_id, event_id, name, rule_set_id) values
  ('60000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '男子個人', '40000000-0000-0000-0000-000000000001');

insert into public.courts (id, organization_id, event_id, name) values
  ('70000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Aコート'),
  ('70000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Bコート');

insert into public.court_grants (court_id, user_id, organization_id, expires_at) values
  ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d', '10000000-0000-0000-0000-000000000001', now() + interval '1 day');

insert into public.entries (id, organization_id, division_id, athlete_id, status) values
  ('80000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-00000000000a', 'approved');

insert into public.brackets (id, organization_id, division_id)
  values ('90000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001');
insert into public.matches (id, organization_id, bracket_id, round, slot, court_id) values
  ('a0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001', 1, 0, '70000000-0000-0000-0000-000000000001'),
  ('a0000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001', 1, 1, '70000000-0000-0000-0000-000000000002');

-- ------------------------------------------------------------------
-- 判定用の小さな関数
-- ------------------------------------------------------------------
create function pg_temp.expect(ok boolean, label text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'FAILED: %', label; end if;
  raise notice 'ok: %', label;
end $$;

create function pg_temp.as_user(uid text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid, ''), true);
  if uid is null then execute 'set local role anon'; else execute 'set local role authenticated'; end if;
end $$;

-- ------------------------------------------------------------------
-- 1. 一般の閲覧者（ログインなし）
-- ------------------------------------------------------------------
begin;
select pg_temp.as_user(null);
select pg_temp.expect((select count(*) from public.events) = 1, '閲覧者は公開中の大会だけ見える（下書きは見えない）');
select pg_temp.expect((select count(*) from public.athletes) = 0, '閲覧者は選手の基本テーブルを読めない');
select pg_temp.expect((select count(*) from public.public_athletes) = 2, '閲覧者は公開用の選手 view は読める');
select pg_temp.expect((select grade from public.public_athletes where name = '選手A') is null, '非公開の学年は view に出ない');
select pg_temp.expect((select count(*) from public.entries) = 0, '閲覧者はエントリーの基本テーブルを読めない');
select pg_temp.expect((select count(*) from public.public_entries) = 1, '閲覧者は承認済みエントリーの view は読める');
select pg_temp.expect((select count(*) from public.matches) = 2, '閲覧者は公開中の大会の試合を読める');
rollback;

begin;
select pg_temp.as_user(null);
do $$ begin
  begin
    perform 1 from public.court_secrets;
    raise exception 'FAILED: 閲覧者が court_secrets を読めた';
  exception when insufficient_privilege then raise notice 'ok: 閲覧者は PIN のハッシュを読めない';
  end;
end $$;
rollback;

-- ------------------------------------------------------------------
-- 2. 大学の代表
-- ------------------------------------------------------------------
begin;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select pg_temp.expect((select count(*) from public.athletes) = 1, '大学Aの代表は自校の選手だけ読める');
update public.athletes set name = '書き換え' where id = '30000000-0000-0000-0000-00000000000b';
select pg_temp.expect(not exists (select 1 from public.athletes where name = '書き換え'), '大学Aの代表は他校の選手を更新できない（0行）');
rollback;

begin;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
-- 大学Bの代表が自校の選手を申し込む → 成功
insert into public.entries (organization_id, division_id, athlete_id)
  values ('10000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-00000000000b');
select pg_temp.expect(true, '大学Bの代表は受付期間中に自校の選手を申し込める');
rollback;

begin;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
do $$ begin
  begin
    insert into public.entries (organization_id, division_id, athlete_id)
      values ('10000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-00000000000a');
    raise exception 'FAILED: 他校の選手を申し込めた';
  exception when insufficient_privilege then raise notice 'ok: 代表は他校の選手を申し込めない';
  end;
end $$;
rollback;

begin;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
update public.entries set paid_reported_at = now() where id = '80000000-0000-0000-0000-00000000000a';
select pg_temp.expect((select paid_reported_at is not null from public.entries where id = '80000000-0000-0000-0000-00000000000a'), '代表は振込済みを申告できる');
do $$ begin
  begin
    update public.entries set paid_confirmed_at = now() where id = '80000000-0000-0000-0000-00000000000a';
    raise exception 'FAILED: 代表が入金確認を書き換えた';
  exception when raise_exception then
    if sqlerrm like 'FAILED%' then raise; end if;
    raise notice 'ok: 代表は入金の確認（運営の仕事）を書き換えられない';
  end;
end $$;
rollback;

-- ------------------------------------------------------------------
-- 3. 審判端末
-- ------------------------------------------------------------------
begin;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
insert into public.match_events (organization_id, match_id, seq, type, side, at, device_id)
  values ('10000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1, 'point', 'red', now(), 'tab-1');
select pg_temp.expect(true, '審判は担当コートの試合を採点できる');
do $$ begin
  begin
    insert into public.match_events (organization_id, match_id, seq, type, side, at, device_id)
      values ('10000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 1, 'point', 'red', now(), 'tab-1');
    raise exception 'FAILED: 担当外のコートを採点できた';
  exception when insufficient_privilege then raise notice 'ok: 審判は担当外のコートを採点できない';
  end;
end $$;
do $$ begin
  begin
    update public.match_events set side = 'white' where match_id = 'a0000000-0000-0000-0000-000000000001';
    raise exception 'FAILED: 採点記録を書き換えられた';
  exception when insufficient_privilege then raise notice 'ok: 採点記録は書き換えられない（追記のみ）';
  end;
end $$;
rollback;

-- ------------------------------------------------------------------
-- 4. 選手本人
-- ------------------------------------------------------------------
begin;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.expect((select count(*) from public.athletes) = 1, '選手は自分の情報を読める');
select pg_temp.expect((select count(*) from public.entries) = 1, '選手は自分のエントリーを読める');
rollback;

-- ------------------------------------------------------------------
-- 5. 管理者と操作履歴
-- ------------------------------------------------------------------
begin;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select pg_temp.expect((select count(*) from public.events) = 2, '管理者は下書きの大会も読める');
update public.matches set status = 'finished' where id = 'a0000000-0000-0000-0000-000000000001';
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'matches') = 1, '試合の更新は操作履歴に残る');
rollback;

\echo 'RLS tests passed'
