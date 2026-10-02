import { describe, expect, it } from 'vitest'
import { computeMatchState, nextSeq, type MatchEvent, type RuleSet } from './scoring'

// テスト用の仮の値。実際の値は審判部と確定し、大会ごとの rule_sets に入れる
const rules: RuleSet = { pointsToWin: 2, durationSec: 120, extensionSec: 60, foulsPerPoint: 2 }

describe('computeMatchState', () => {
  it('必要本数に達した側が勝ち', () => {
    const ev: MatchEvent[] = [
      { seq: 1, at: 0, type: 'start' },
      { seq: 2, at: 10_000, type: 'point', side: 'red' },
      { seq: 3, at: 20_000, type: 'point', side: 'white' },
      { seq: 4, at: 30_000, type: 'point', side: 'red' },
    ]
    const s = computeMatchState(ev, rules)
    expect(s.points).toEqual({ red: 2, white: 1 })
    expect(s.winner).toBe('red')
    expect(s.reason).toBe('points')
    expect(s.running).toBe(false)
    expect(s.elapsedMs).toBe(30_000)
  })

  it('取り消し（undo）された本は数えない', () => {
    const ev: MatchEvent[] = [
      { seq: 1, at: 0, type: 'point', side: 'red' },
      { seq: 2, at: 1, type: 'point', side: 'red' },
      { seq: 3, at: 2, type: 'undo', targetSeq: 2 },
    ]
    const s = computeMatchState(ev, rules)
    expect(s.points.red).toBe(1)
    expect(s.winner).toBeNull()
  })

  it('反則が規定回数に達すると相手に1本', () => {
    const ev: MatchEvent[] = [
      { seq: 1, at: 0, type: 'foul', side: 'white' },
      { seq: 2, at: 1, type: 'foul', side: 'white' },
    ]
    const s = computeMatchState(ev, rules)
    expect(s.fouls.white).toBe(2)
    expect(s.points.red).toBe(1)
  })

  it('記録の到着順が前後しても seq 順で計算する（オフライン同期）', () => {
    const ev: MatchEvent[] = [
      { seq: 3, at: 3, type: 'point', side: 'red' },
      { seq: 1, at: 1, type: 'point', side: 'white' },
      { seq: 2, at: 2, type: 'point', side: 'white' },
    ]
    const s = computeMatchState(ev, rules)
    expect(s.winner).toBe('white')
    expect(s.points.red).toBe(0) // 白の勝ちが決まった後の本は数えない
  })

  it('判定と確定。確定後の記録は無視', () => {
    const ev: MatchEvent[] = [
      { seq: 1, at: 0, type: 'decision', side: 'white' },
      { seq: 2, at: 1, type: 'confirm' },
      { seq: 3, at: 2, type: 'decision', side: 'red' },
    ]
    const s = computeMatchState(ev, rules)
    expect(s.winner).toBe('white')
    expect(s.confirmed).toBe(true)
  })

  it('勝者が決まる前の確定は無効', () => {
    const s = computeMatchState([{ seq: 1, at: 0, type: 'confirm' }], rules)
    expect(s.confirmed).toBe(false)
  })

  it('進行中は now までの時間を含め、本戦時間を超えたら延長', () => {
    const s = computeMatchState([{ seq: 1, at: 0, type: 'start' }], rules, 130_000)
    expect(s.running).toBe(true)
    expect(s.elapsedMs).toBe(130_000)
    expect(s.inExtension).toBe(true)
  })

  it('nextSeq', () => {
    expect(nextSeq([])).toBe(1)
    expect(nextSeq([{ seq: 7, at: 0, type: 'start' }])).toBe(8)
  })
})
