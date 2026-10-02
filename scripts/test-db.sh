#!/usr/bin/env bash
# 素の PostgreSQL に Supabase の模造品とマイグレーションを流し、RLS テストを実行する。
# 例: PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres ./scripts/test-db.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${TEST_DB:-kempo_hub_test}"
psql -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
psql -v ON_ERROR_STOP=1 -q -d "$DB" -f supabase/tests/stub_supabase.sql
for f in supabase/migrations/*.sql; do
  psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$f"
done
psql -v ON_ERROR_STOP=1 -q -t -o /dev/null -d "$DB" -f supabase/tests/rls.test.sql 2>&1 | sed "s/^psql:[^ ]* NOTICE:  //"
