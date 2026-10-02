import { useTranslation } from 'react-i18next'

export default function Placeholder({ id, title }: { id: string; title: string }) {
  const { t } = useTranslation()
  return (
    <section>
      <h1 className="text-xl font-bold">{title}</h1>
      <p className="mt-2 text-sm text-gray-600">{t('comingSoon', { id })}</p>
    </section>
  )
}
