# AI 開発ルール（Claude Code / Codex 共通）

このファイルと AGENTS.md は同じ内容にしておくこと。片方を変えたら、もう片方も同じに直す。

## まず読むもの

- 作業の前に必ず `docs/spec.md` の該当する機能ID（例: `ADM-04`）と「6. データ設計」「7. 権限」を読む
- 仕様に書いていないことを決める必要が出たら、勝手に決めずに質問するか、PR の説明に「仮で決めたこと」として明記する

## 技術構成

- React 19 + Vite + TypeScript（strict）+ Tailwind CSS 4 + React Router 7 + TanStack Query
- Supabase（PostgreSQL + RLS、Auth、Realtime、Edge Functions、Storage）
- 公開先は Cloudflare Pages（静的ファイルのみ。サーバー側の処理は Supabase の Edge Functions に置く）
- テスト: Vitest（`src/**/*.test.ts`）、Playwright（`e2e/`）、RLS（`supabase/tests/rls.test.sql`）

## フォルダと命名

- `src/lib/` … 画面に依存しない計算ロジック。必ず単体テストを同じ場所に置く（`xxx.test.ts`）
- `src/pages/` … 画面（1画面1ファイル、PascalCase）。`src/components/` … 共通部品
- `src/i18n/ja.json` … 画面の文言。日本語の文言を TSX に直書きしてよいのは開発中のみ。PR 前に ja.json へ移す
- `supabase/migrations/` … `YYYYMMDDHHMMSS_説明.sql`。既存のマイグレーションは書き換えず、新しいファイルを追加する
- ブランチ名: `feat/ADM-04-bracket`、`fix/REF-03-undo` のように機能IDを入れる
- コミットメッセージ: `ADM-04: 組合せ生成で同じ所属を初戦で避ける` のように機能IDから始める

## データの原則

- 全テーブルに `organization_id` を持たせる
- 全テーブルで RLS を有効にする。新しいテーブルには必ずポリシーと `supabase/tests/rls.test.sql` のテストを追加する
- 試合の結果は `match_events`（採点記録）が正。勝者・本数は `src/lib/scoring.ts` で記録から計算する。`match_events` は追記のみ（更新・削除しない。取り消しは `undo` の記録を足す）
- 試合ルールの値（何本で勝ちか、試合時間、延長、反則の扱い）はコードに書かない。`rule_sets` から読む
- 観客向けの画面はリアルタイム接続を使わず、`live_snapshots` を30秒ごとに取得する（無料枠の同時接続200を守るため）。Realtime を使ってよいのは審判・運営・大学代表の画面だけ
- 個人情報は仕様にある項目だけ。住所・生年月日・電話番号は持たない。公開画面は `public_athletes` などの view を使う

## 禁止事項

- `service_role` キーや秘密情報を画面側のコード・リポジトリに置かない（`.env.local` と GitHub Secrets のみ）
- RLS のないテーブルを作らない。RLS を無効にしない
- `main` に直接 push しない。PR をマージするのは人間だけ
- 既存のマイグレーションファイルを書き換えない
- テストを消したり `skip` にしたりして通さない
- 決済機能を作らない（入金は「振込済み」の申告と運営の確認だけ）
- Smoothcomp など他サービスのコード・デザインを写さない（機能の考え方を参考にするのはよい）

## 作業の終わりに必ずやること

```bash
npm run lint && npm run build && npm test
npm run test:db   # マイグレーションや RLS を変えたとき（PostgreSQL が必要）
npm run test:e2e  # 画面を変えたとき
```

PR の説明には次を書く:

1. 対応した機能ID と、spec.md の「完成の条件」をどう満たしたか
2. 仮で決めたこと・仕様と違うこと
3. 人が確認用 URL で触って確かめてほしい操作の手順

## 分担（目安）

| 作業 | 担当 |
| --- | --- |
| データ設計、RLS、マイグレーション | Claude Code |
| 組合せ生成、トーナメント進行、時間割の計算 | Claude Code |
| 審判画面のオフライン同期 | Claude Code |
| 公開サイトと管理画面の各画面、テストの追加、小さな修正 | Codex |
| レビュー | 書いていない方の AI |
| 仕様の決定、ルールの確認、マージ | 人 |
