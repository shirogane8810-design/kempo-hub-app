import { Route, Routes } from 'react-router-dom'
import Layout from './components/Layout'
import Placeholder from './pages/Placeholder'
import Home from './pages/Home'

/**
 * URL 構成は docs/spec.md 「3. 画面全体図」に合わせる。
 * Placeholder の id は機能ID。実装したら各画面のコンポーネントに置き換える。
 */
export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Home />} />
        <Route path="schedule" element={<Placeholder id="PUB-02" title="年間スケジュール" />} />
        <Route path="events/:eventSlug" element={<Placeholder id="PUB-03" title="大会ページ" />} />
        <Route path="events/:eventSlug/brackets/:divisionId" element={<Placeholder id="PUB-04" title="トーナメント表" />} />
        <Route path="events/:eventSlug/courts" element={<Placeholder id="PUB-05" title="コート別の進行" />} />
        <Route path="matches/:matchId" element={<Placeholder id="PUB-06" title="試合の詳細" />} />
        <Route path="me" element={<Placeholder id="ATH-02 / TEAM-04" title="マイページ" />} />
        <Route path="admin/*" element={<Placeholder id="ADM-01" title="運営の管理画面" />} />
        <Route path="sponsor/:reportKey" element={<Placeholder id="SPN-01" title="広告レポート" />} />
        <Route path="*" element={<Placeholder id="404" title="ページが見つかりません" />} />
      </Route>
      {/* 審判画面はタブレット全画面で使うので共通レイアウトの外 */}
      <Route path="ref/*" element={<Placeholder id="REF-01" title="審判画面" />} />
    </Routes>
  )
}
