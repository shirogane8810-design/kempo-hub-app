import { useTranslation } from 'react-i18next'
import { isSupabaseConfigured } from '../lib/supabase'

export default function Home() {
  const { t } = useTranslation()
  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-bold">{t('appName')}</h1>
      <p className="text-gray-700">申込から結果まで、日本拳法の大会をひとつのサイトで。</p>
      {!isSupabaseConfigured && (
        <p className="rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900">
          {t('notConfigured')}
        </p>
      )}
    </section>
  )
}
