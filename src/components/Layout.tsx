import { useTranslation } from 'react-i18next'
import { NavLink, Outlet } from 'react-router-dom'

const linkClass = ({ isActive }: { isActive: boolean }) =>
  `px-3 py-2 rounded-md text-sm ${isActive ? 'bg-gray-900 text-white' : 'text-gray-700 hover:bg-gray-100'}`

export default function Layout() {
  const { t } = useTranslation()
  return (
    <div className="min-h-dvh bg-white text-gray-900">
      <header className="border-b border-gray-200">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center gap-2 px-4 py-3">
          <NavLink to="/" className="mr-4 font-bold">
            {t('appName')}
          </NavLink>
          <nav className="flex flex-wrap gap-1">
            <NavLink to="/schedule" className={linkClass}>
              {t('nav.schedule')}
            </NavLink>
            <NavLink to="/me" className={linkClass}>
              {t('nav.me')}
            </NavLink>
            <NavLink to="/admin" className={linkClass}>
              {t('nav.admin')}
            </NavLink>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  )
}
