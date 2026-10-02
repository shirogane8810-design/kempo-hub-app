/**
 * トーナメント（シングルエリミネーション）の組合せ生成。仕様: docs/spec.md ADM-04
 *
 * - シード指定された選手を標準のシード位置に置く
 * - 不戦勝（bye）は上位シードから順に与える
 * - 同じ所属同士が初戦で当たらないように入れ替える（できる範囲で）
 * - 乱数はシード値つきで決定的（同じ入力なら同じ結果）。テストと再現のため
 */

export type Entrant = {
  id: string
  clubId: string
  /** 1 が第1シード。未指定はノーシード */
  seed?: number
}

export type Slot = Entrant | null

export type BracketMatch = {
  round: number // 1 = 1回戦
  slot: number // その回戦の中での番号（0始まり）
  red: Slot
  white: Slot
  /** 勝者が進む試合。決勝は null */
  next: { round: number; slot: number; side: 'red' | 'white' } | null
  /** 片方が不在で、試合をせずに勝ち上がる */
  isBye: boolean
}

export type GenerateOptions = {
  avoidSameClub?: boolean
  /** シャッフル用の乱数シード */
  randomSeed?: number
}

export function nextPowerOfTwo(n: number): number {
  if (n < 1) return 1
  let p = 1
  while (p < n) p *= 2
  return p
}

/** 標準のシード配置順。size=8 なら [1,8,4,5,2,7,3,6]（各要素は順位） */
export function seedOrder(size: number): number[] {
  let order = [1]
  while (order.length < size) {
    const n = order.length * 2
    order = order.flatMap((r) => [r, n + 1 - r])
  }
  return order
}

function mulberry32(seed: number): () => number {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function shuffle<T>(items: T[], rand: () => number): T[] {
  const a = [...items]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

/** 1回戦の並び（長さ = 2のべき乗）を作る */
export function placeEntrants(entrants: Entrant[], options: GenerateOptions = {}): Slot[] {
  const { avoidSameClub = true, randomSeed = 1 } = options
  if (entrants.length === 0) return []
  const ids = new Set(entrants.map((e) => e.id))
  if (ids.size !== entrants.length) throw new Error('同じ選手が重複しています')

  const rand = mulberry32(randomSeed)
  const seeded = entrants
    .filter((e) => e.seed !== undefined)
    .sort((a, b) => (a.seed as number) - (b.seed as number))
  const unseeded = shuffle(
    entrants.filter((e) => e.seed === undefined),
    rand,
  )
  const ranked = [...seeded, ...unseeded]

  const size = nextPowerOfTwo(Math.max(2, ranked.length))
  const slots: Slot[] = seedOrder(size).map((rank) => ranked[rank - 1] ?? null)

  if (avoidSameClub) separateSameClub(slots)
  return slots
}

function clash(a: Slot, b: Slot): boolean {
  return !!a && !!b && a.clubId === b.clubId
}

/**
 * 初戦で同じ所属が当たる組を、ノーシード選手どうしの入れ替えで解消する。
 * シード選手は動かさない。解消できない組は残る（所属が偏っている場合）。
 */
function separateSameClub(slots: Slot[]): void {
  const pairs = slots.length / 2
  for (let p = 0; p < pairs; p++) {
    const i = p * 2
    if (!clash(slots[i], slots[i + 1])) continue
    // 動かせる方（ノーシード）を選ぶ
    const moveIdx = slots[i + 1]?.seed === undefined ? i + 1 : slots[i]?.seed === undefined ? i : -1
    if (moveIdx < 0) continue
    const stayIdx = moveIdx === i ? i + 1 : i

    for (let k = 0; k < slots.length; k++) {
      if (k === i || k === i + 1) continue
      const cand = slots[k]
      if (!cand || cand.seed !== undefined) continue
      const partnerIdx = k % 2 === 0 ? k + 1 : k - 1
      const mover = slots[moveIdx]
      // 入れ替え後、両方の組で衝突しないこと
      if (clash(cand, slots[stayIdx])) continue
      if (clash(mover, slots[partnerIdx])) continue
      slots[k] = mover
      slots[moveIdx] = cand
      break
    }
  }
}

/** 1回戦の並びから、全試合（決勝まで）を作る */
export function buildMatches(firstRound: Slot[]): BracketMatch[] {
  const size = firstRound.length
  if (size < 2 || (size & (size - 1)) !== 0) throw new Error('枠数は2のべき乗である必要があります')
  const rounds = Math.log2(size)
  const matches: BracketMatch[] = []

  for (let r = 1; r <= rounds; r++) {
    const count = size / 2 ** r
    for (let s = 0; s < count; s++) {
      const next =
        r === rounds
          ? null
          : { round: r + 1, slot: Math.floor(s / 2), side: (s % 2 === 0 ? 'red' : 'white') as 'red' | 'white' }
      const red = r === 1 ? firstRound[s * 2] : null
      const white = r === 1 ? firstRound[s * 2 + 1] : null
      matches.push({ round: r, slot: s, red, white, next, isBye: r === 1 && (!red || !white) })
    }
  }

  // 1回戦の不戦勝を次の試合へ進めておく
  for (const m of matches.filter((x) => x.round === 1 && x.isBye)) {
    const winner = m.red ?? m.white
    if (!winner || !m.next) continue
    const target = matches.find((x) => x.round === m.next!.round && x.slot === m.next!.slot)
    if (target) target[m.next.side] = winner
  }
  return matches
}

export function generateBracket(entrants: Entrant[], options: GenerateOptions = {}): BracketMatch[] {
  return buildMatches(placeEntrants(entrants, options))
}
