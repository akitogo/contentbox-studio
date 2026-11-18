import type { ReactNode } from 'react'
import { Link } from 'react-router'
import { useStudio } from '../studio'

export function Header({ children }: { children?: ReactNode }) {
  const { config, api, me } = useStudio()

  async function logout() {
    try {
      await api.post(`${config.contentboxApi}/logout`)
    } finally {
      window.location.href = config.logoutUrl
    }
  }

  return (
    <header className="studio-header">
      <Link to="/" className="studio-brand">
        ContentBox Studio <small>{config.version}</small>
      </Link>
      <div className="studio-header__middle">{children}</div>
      <nav className="studio-nav">
        <span className="studio-user">
          {me.name} <small>{me.role}</small>
        </span>
        <a href={config.adminUrl}>Classic admin</a>
        <button type="button" onClick={logout}>
          Log out
        </button>
      </nav>
    </header>
  )
}
