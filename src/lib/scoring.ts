/**
 * 採点記録（match_events）から試合の状態を計算する。仕様: docs/spec.md REF-03, REF-04, 6章
 *
 * 試合の結果は採点記録を正とし、勝者などはここで毎回計算する。
 * ルールの具体的な値（何本で勝ちか、試合時間など）は RuleSet で渡し、コードに書き込まない。
 */

export type Side = 'red' | 'white'

export type RuleSet = {
  /** 勝ちに必要な本数 */
  pointsToWin: number
  /** 本戦の試合時間（秒） */
  durationSec: number
  /** 延長の時間（秒）。0 なら延長なし */
  extensionSec: number
  /** 反則が何回で相手に1本与えるか。null なら反則で本数は動かない */
  foulsPerPoint: number | null
}

export type MatchEvent =
  | { seq: number; at: number; type: 'start' }
  | { seq: number; at: number; type: 'stop' }
  | { seq: number; at: number; type: 'point'; side: Side }
  | { seq: number; at: number; type: 'foul'; side: Side }
  | { seq: number; at: number; type: 'decision'; side: Side }
  | { seq: number; at: number; type: 'walkover'; side: Side }
  | { seq: number; at: number; type: 'undo'; targetSeq: number }
  | { seq: number; at: number; type: 'confirm' }

export type WinReason = 'points' | 'decision' | 'walkover'

export type MatchState = {
  points: Record<Side, number>
  fouls: Record<Side, number>
  winner: Side | null
  reason: WinReason | null
  running: boolean
  /** 経過時間（ミリ秒）。now を渡すと進行中の時間も含める */
  elapsedMs: number
  inExtension: boolean
  confirmed: boolean
}

const other = (s: Side): Side => (s === 'red' ? 'white' : 'red')

/** 取り消された記録を除いた、有効な記録を返す（seq 順） */
export function effectiveEvents(events: MatchEvent[]): MatchEvent[] {
  const sorted = [...events].sort((a, b) => a.seq - b.seq)
  const undone = new Set<number>()
  for (const e of sorted) {
    if (e.type === 'undo') undone.add(e.targetSeq)
  }
  return sorted.filter((e) => e.type !== 'undo' && !undone.has(e.seq))
}

export function computeMatchState(events: MatchEvent[], rules: RuleSet, now?: number): MatchState {
  const state: MatchState = {
    points: { red: 0, white: 0 },
    fouls: { red: 0, white: 0 },
    winner: null,
    reason: null,
    running: false,
    elapsedMs: 0,
    inExtension: false,
    confirmed: false,
  }
  let startedAt: number | null = null

  for (const e of effectiveEvents(events)) {
    if (state.confirmed) break // 確定後の記録は無視（修正は運営が別手順で行う）
    switch (e.type) {
      case 'start':
        if (!state.running && !state.winner) {
          state.running = true
          startedAt = e.at
        }
        break
      case 'stop':
        if (state.running && startedAt !== null) {
          state.elapsedMs += e.at - startedAt
          state.running = false
          startedAt = null
        }
        break
      case 'point':
        if (!state.winner) state.points[e.side] += 1
        break
      case 'foul':
        if (!state.winner) {
          state.fouls[e.side] += 1
          if (rules.foulsPerPoint && state.fouls[e.side] % rules.foulsPerPoint === 0) {
            state.points[other(e.side)] += 1
          }
        }
        break
      case 'decision':
        if (!state.winner) {
          state.winner = e.side
          state.reason = 'decision'
        }
        break
      case 'walkover':
        if (!state.winner) {
          state.winner = e.side
          state.reason = 'walkover'
        }
        break
      case 'confirm':
        if (state.winner) state.confirmed = true
        break
    }
    if (!state.winner) {
      for (const s of ['red', 'white'] as const) {
        if (state.points[s] >= rules.pointsToWin) {
          state.winner = s
          state.reason = 'points'
        }
      }
    }
    if (state.winner && state.running && startedAt !== null) {
      state.elapsedMs += e.at - startedAt
      state.running = false
      startedAt = null
    }
  }

  if (state.running && startedAt !== null && now !== undefined) {
    state.elapsedMs += Math.max(0, now - startedAt)
  }
  state.inExtension = rules.extensionSec > 0 && state.elapsedMs > rules.durationSec * 1000
  return state
}

/** 次に記録する seq（端末内で採番。オフライン時も順序が保てる） */
export function nextSeq(events: MatchEvent[]): number {
  return events.reduce((m, e) => Math.max(m, e.seq), 0) + 1
}
