import { describe, expect, it } from 'vitest'
import { buildMatches, generateBracket, nextPowerOfTwo, placeEntrants, seedOrder, type Entrant } from './bracket'

const mk = (n: number, clubOf: (i: number) => string = (i) => `c${i}`): Entrant[] =>
  Array.from({ length: n }, (_, i) => ({ id: `a${i + 1}`, clubId: clubOf(i) }))

describe('seedOrder', () => {
  it('8枠の標準配置', () => {
    expect(seedOrder(8)).toEqual([1, 8, 4, 5, 2, 7, 3, 6])
  })
  it('第1シードと第2シードは決勝まで当たらない（別の山）', () => {
    const order = seedOrder(16)
    expect(order.indexOf(1) < 8).toBe(true)
    expect(order.indexOf(2) >= 8).toBe(true)
  })
})

describe('placeEntrants', () => {
  it('枠数は2のべき乗になり、全員が1回ずつ入る', () => {
    const slots = placeEntrants(mk(11))
    expect(slots).toHaveLength(nextPowerOfTwo(11))
    const ids = slots.filter(Boolean).map((s) => s!.id)
    expect(new Set(ids).size).toBe(11)
  })

  it('不戦勝は上位シードに与えられる', () => {
    const entrants = mk(6)
    entrants[0].seed = 1
    entrants[1].seed = 2
    const slots = placeEntrants(entrants, { avoidSameClub: false })
    // 8枠・6人 → 不戦勝2つ。第1・第2シードの相手が空
    const pairOf = (id: string) => {
      const i = slots.findIndex((s) => s?.id === id)
      return slots[i % 2 === 0 ? i + 1 : i - 1]
    }
    expect(pairOf('a1')).toBeNull()
    expect(pairOf('a2')).toBeNull()
  })

  it('同じ入力と乱数シードなら同じ結果になる', () => {
    const a = placeEntrants(mk(13), { randomSeed: 42 })
    const b = placeEntrants(mk(13), { randomSeed: 42 })
    expect(a.map((s) => s?.id ?? null)).toEqual(b.map((s) => s?.id ?? null))
  })

  it('同じ所属どうしが初戦で当たらない（解消できる場合）', () => {
    // 16人・4所属×4人
    for (let seed = 1; seed <= 30; seed++) {
      const slots = placeEntrants(
        mk(16, (i) => `club${i % 4}`),
        { randomSeed: seed },
      )
      for (let p = 0; p < slots.length; p += 2) {
        expect(slots[p]!.clubId).not.toBe(slots[p + 1]!.clubId)
      }
    }
  })

  it('選手の重複はエラー', () => {
    expect(() => placeEntrants([{ id: 'x', clubId: 'a' }, { id: 'x', clubId: 'b' }])).toThrow()
  })
})

describe('buildMatches', () => {
  it('8枠なら 4+2+1 = 7試合、決勝の次はない', () => {
    const matches = buildMatches(placeEntrants(mk(8)))
    expect(matches).toHaveLength(7)
    const final = matches.find((m) => m.round === 3)!
    expect(final.next).toBeNull()
  })

  it('不戦勝の選手は2回戦に自動で進む', () => {
    const entrants = mk(5)
    entrants[0].seed = 1
    const matches = generateBracket(entrants, { avoidSameClub: false })
    const byeMatch = matches.find((m) => m.round === 1 && (m.red?.id === 'a1' || m.white?.id === 'a1'))!
    expect(byeMatch.isBye).toBe(true)
    const r2 = matches.find((m) => m.round === 2 && (m.red?.id === 'a1' || m.white?.id === 'a1'))
    expect(r2).toBeDefined()
  })
})
