# P1（新人戦版）の作業リスト

上から順に着手する。1行 = 1 Issue。「担当」は CLAUDE.md の分担の目安。

| 週 | 機能ID | 内容 | 担当 | 状態 |
| --- | --- | --- | --- | --- |
| 10/3〜 | ― | プロジェクトの土台、CI、P1 のスキーマと RLS | Claude Code | 済 |
| 10/3〜 | ADM-04（計算） | 組合せ生成ロジック `src/lib/bracket.ts` | Claude Code | 済 |
| 10/3〜 | REF-03/04（計算） | 採点計算ロジック `src/lib/scoring.ts` | Claude Code | 済 |
| 10/3〜 | ― | Supabase プロジェクト作成・接続、Cloudflare Pages 接続 | 人 | |
| 10/13〜 | COM-01 | ログイン（Google・メール）、profiles の自動作成 | Claude Code | |
| 10/13〜 | ADM-11 | 権限の付与画面、操作履歴の閲覧 | Codex | |
| 10/13〜 | ADM-02 | 大会・部門・ルールセット・コートの作成 | Codex | |
| 10/13〜 | TEAM-01 / ATH-01 | 所属の登録、招待リンク、選手の登録・代理登録 | Codex | |
| 10/13〜 | TEAM-02 / TEAM-03 | 個人戦エントリー、振込済みの申告 | Codex | |
| 10/13〜 | ADM-03 | エントリーの承認・入金確認・CSV 出力 | Codex | |
| 10/13〜 | PUB-01〜03 | トップ、年間スケジュール、大会ページ | Codex | |
| 10/27〜 | ADM-04（画面） | 組合せ生成の画面、手での入れ替え、確定ロック | Claude Code | |
| 10/27〜 | ADM-05 | 時間割の編成、予想時刻の計算 | Claude Code | |
| 10/27〜 | ADM-06 / REF-01 | 審判の管理、PIN 発行、Edge Function `verify-court-pin` | Claude Code | |
| 10/27〜 | REF-02〜05 | 審判画面（呼び出し、採点、確定、オフライン同期） | Claude Code | |
| 10/27〜 | ― | Edge Function `confirm-match`（勝者確定 → 次の試合へ → live_snapshots 更新） | Claude Code | |
| 11/10〜 | PUB-04〜07 | トーナメント表、コート別の進行、試合の詳細、結果 | Codex | |
| 11/10〜 | PUB-08 / COM-03 | フォローとプッシュ通知（Edge Function `send-push`） | Claude Code | |
| 11/10〜 | ATH-02 / ATH-03 / ADM-08 | マイ大会、受付 QR、QR 読み取り | Codex | |
| 11/10〜 | ADM-07 / ADM-01 | 当日の進行管理、ダッシュボード | Codex | |
| 11/10〜 | ADM-09 / ADM-10 / PUB-09 | お知らせ配信、協賛管理、広告枠 | Codex | |
| 11/10〜 | ADM-12 / TEAM-04 / COM-02 / COM-04 | データ出力、自校の試合一覧、PWA 仕上げ、規約 | Codex | |
| 11/24〜 | ― | 練習試合でリハーサル、通信量の計測、修正 | 全員 | |
