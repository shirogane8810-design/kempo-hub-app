# kempo-hub-app

日本拳法の大会を、申込から結果公開までひとつのサイトで回す「大会ハブ」。運営は一般社団法人 NIKKEN NEXT。

- 12月の全国新人戦で最小版（P1）を実戦投入し、来年の総合選手権までに全機能をそろえる
- 運用費は0円（Cloudflare Pages と Supabase の無料プラン）
- 開発は Claude Code と Codex に実装させ、人は仕様の決定・確認・マージに集中する

仕様の正本は [docs/spec.md](docs/spec.md)。機能ID（`PUB-04` など）は Issue 名・ブランチ名にそのまま使う。

## 何ができるか（予定）

| 利用者 | 主な機能 |
| --- | --- |
| 観客・ファン | 年間スケジュール、大会ページ、トーナメント表（自動更新）、コート別の進行、選手フォローと出番通知 |
| 選手 | プロフィール、マイ大会、受付QR、通算戦績 |
| 大学・道場の代表 | 所属選手の管理、エントリー、入金の申告、団体戦オーダー |
| 審判 | PINでコートに入る、採点（本数・反則・時間）、結果の確定、オフライン採点 |
| 運営 | 大会作成、組合せ生成、時間割、当日の進行管理、受付、お知らせ、協賛広告の管理 |
| 協賛企業 | 広告の表示数・クリック数のレポート |

## 技術構成

| 用途 | 技術 |
| --- | --- |
| 画面 | React 19 + Vite + TypeScript + Tailwind CSS 4、PWA |
| データ・ログイン・リアルタイム・サーバー処理 | Supabase（PostgreSQL + RLS、Auth、Realtime、Edge Functions、Storage） |
| 公開先 | Cloudflare Pages（Vercel の無料プランは広告を載せるサイトが対象外のため使わない） |
| テスト | Vitest（計算ロジック）、Playwright（画面）、素の PostgreSQL での RLS テスト |
| CI | GitHub Actions（PR ごとに lint・ビルド・テスト・DBテスト） |

## はじめかた

必要なもの: Node.js 22 以上、PostgreSQL のクライアント（DBテストを動かす場合）

```bash
npm install
cp .env.example .env.local   # Supabase の URL と anon key を入れる
npm run dev                  # http://localhost:5173
```

Supabase が未設定でも画面は起動する（トップに設定を促す表示が出る）。

### よく使うコマンド

| コマンド | 内容 |
| --- | --- |
| `npm run dev` | 開発サーバー |
| `npm run build` | 型チェック + 本番ビルド（`dist/`） |
| `npm run lint` | oxlint |
| `npm test` | 単体テスト（組合せ生成・採点計算など） |
| `npm run test:e2e` | 画面のテスト（Playwright） |
| `npm run test:db` | マイグレーションと RLS（権限）のテスト。`PGHOST` などで接続先の PostgreSQL を指定 |

### Supabase につなぐ

1. Supabase で本番用と開発用の2プロジェクトを作る（無料プランは2つまで）
2. `npx supabase login` → `npx supabase link --project-ref <開発用のref>`
3. `npx supabase db push` でマイグレーションを反映
4. Project Settings > API の URL と anon key を `.env.local` に入れる
5. Authentication > Providers で Google とメールを有効にし、審判端末用に Anonymous sign-ins を有効にする

### 公開（Cloudflare Pages）

- Cloudflare Pages でこのリポジトリをつなぎ、ビルドコマンド `npm run build`、出力先 `dist` を指定
- 環境変数に `VITE_SUPABASE_URL` と `VITE_SUPABASE_ANON_KEY` を登録
- `main` にマージすると本番、PR ごとに確認用 URL が自動で発行される

## フォルダ構成

```
src/
  lib/          計算ロジック（bracket.ts: 組合せ生成、scoring.ts: 採点計算）とテスト
  pages/        画面
  components/   共通部品
  i18n/         文言（日本語。英語は P3）
supabase/
  migrations/   データベースの変更（RLS を含む）
  tests/        RLS のテスト
e2e/            Playwright のテスト
docs/           仕様書
.github/        CI と Supabase の休止防止
```

## 開発の進め方

1. 機能IDごとに Issue を作る（完成の条件を3〜5個書く）
2. 1 Issue = 1 ブランチ = 1 プルリクエスト。`main` に直接 push しない
3. 難所（DB・権限・組合せ・進行・オフライン同期）は Claude Code、画面の量産とテストは Codex。書いていない方のAIがレビューする
4. 自動テストが通り、人が確認用 URL で触って問題なければマージ
5. 大会の3日前から大会後までは新機能を本番に入れない

AI 向けのルールは [CLAUDE.md](CLAUDE.md)（[AGENTS.md](AGENTS.md) も同じ内容）にある。

## 現在の状況

- [x] プロジェクトの土台（画面の骨組み、ルーティング、PWA、CI）
- [x] P1 のデータベース設計と RLS（権限テスト 21 件）
- [x] 組合せ生成（ADM-04 の計算部分）と採点計算（REF-03/04 の計算部分）
- [ ] Supabase プロジェクトの作成と接続
- [ ] P1 の各画面（docs/spec.md の機能一覧を参照）
